import Foundation
import SQLite3

final class SQLiteConnection: @unchecked Sendable {
    var db: OpaquePointer?
    
    init(path: String) {
        var handle: OpaquePointer?
        if sqlite3_open(path, &handle) == SQLITE_OK {
            sqlite3_exec(handle, "PRAGMA journal_mode=WAL;", nil, nil, nil)
            sqlite3_exec(handle, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
            
            let createRawTable = """
            CREATE TABLE IF NOT EXISTS telemetry_raw (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp REAL NOT NULL,
                cpu_usage REAL NOT NULL,
                ram_used_bytes INTEGER NOT NULL,
                ram_pressure INTEGER NOT NULL,
                disk_used_bytes INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_telemetry_timestamp ON telemetry_raw(timestamp);
            """
            sqlite3_exec(handle, createRawTable, nil, nil, nil)
        }
        self.db = handle
    }
    
    deinit {
        if let handle = db {
            sqlite3_close(handle)
        }
    }
}

/// Point model for telemetry queries
public struct TelemetryHistoryPoint: Identifiable, Sendable, Equatable {
    public let id: Int64
    public let timestamp: Date
    public let cpuUsage: Double
    public let ramUsedBytes: UInt64
    public let ramPressureLevel: Int
    public let diskUsedBytes: Int64
    
    public init(
        id: Int64 = 0,
        timestamp: Date,
        cpuUsage: Double,
        ramUsedBytes: UInt64,
        ramPressureLevel: Int,
        diskUsedBytes: Int64
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.ramUsedBytes = ramUsedBytes
        self.ramPressureLevel = ramPressureLevel
        self.diskUsedBytes = diskUsedBytes
    }
}

/// High-performance time-series telemetry storage with automatic downsampling using SQLite.
public actor TelemetryStore {
    public static let shared = TelemetryStore()
    
    private let connection: SQLiteConnection
    
    public init() {
        let appSupport = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.osmancagrigenc.MacOptimizer")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let path = appSupport.appendingPathComponent("telemetry.sqlite").path
        self.connection = SQLiteConnection(path: path)
    }
    
    /// Records an in-memory telemetry snapshot.
    public func record(
        cpuUsage: Double,
        ramUsedBytes: UInt64,
        ramPressureLevel: Int,
        diskUsedBytes: Int64
    ) {
        guard let db = connection.db else { return }
        
        let insertSQL = """
        INSERT INTO telemetry_raw (timestamp, cpu_usage, ram_used_bytes, ram_pressure, disk_used_bytes)
        VALUES (?, ?, ?, ?, ?);
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
            let now = Date().timeIntervalSince1970
            sqlite3_bind_double(stmt, 1, now)
            sqlite3_bind_double(stmt, 2, cpuUsage)
            sqlite3_bind_int64(stmt, 3, Int64(ramUsedBytes))
            sqlite3_bind_int(stmt, 4, Int32(ramPressureLevel))
            sqlite3_bind_int64(stmt, 5, diskUsedBytes)
            
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }
    
    /// Fetches historical telemetry points within the given hour range, downsampled inside SQLite.
    ///
    /// The previous implementation materialised every raw row in the window into Swift structs and
    /// then picked every n-th one — O(rows) allocations on the main user path. Bucketing with
    /// `GROUP BY` returns at most `maxPoints` averaged rows, so memory is bounded by the chart size
    /// regardless of how much history exists.
    public func fetchHistory(hours: Int, maxPoints: Int = 60) -> [TelemetryHistoryPoint] {
        guard let db = connection.db, maxPoints > 0 else { return [] }
        
        let now = Date().timeIntervalSince1970
        let windowSeconds = Double(max(1, hours) * 3600)
        let cutoff = now - windowSeconds
        let bucketSeconds = windowSeconds / Double(maxPoints)
        
        let querySQL = """
        SELECT MIN(id), AVG(timestamp), AVG(cpu_usage), AVG(ram_used_bytes), MAX(ram_pressure), AVG(disk_used_bytes)
        FROM telemetry_raw
        WHERE timestamp >= ?1
        GROUP BY MIN(CAST((timestamp - ?1) / ?2 AS INTEGER), ?3 - 1)
        ORDER BY 2 ASC
        LIMIT ?3;
        """
        
        var stmt: OpaquePointer?
        var points: [TelemetryHistoryPoint] = []
        points.reserveCapacity(maxPoints)
        
        if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, cutoff)
            sqlite3_bind_double(stmt, 2, bucketSeconds)
            sqlite3_bind_int(stmt, 3, Int32(maxPoints))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                points.append(TelemetryHistoryPoint(
                    id: sqlite3_column_int64(stmt, 0),
                    timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                    cpuUsage: sqlite3_column_double(stmt, 2),
                    ramUsedBytes: UInt64(max(0, sqlite3_column_double(stmt, 3))),
                    ramPressureLevel: Int(sqlite3_column_int(stmt, 4)),
                    diskUsedBytes: Int64(sqlite3_column_double(stmt, 5))
                ))
            }
        }
        sqlite3_finalize(stmt)
        return points
    }
    
    private var lastPruneTime: Date?
    
    /// Records one sample and prunes expired rows at most once per hour, so the database stays bounded
    /// (≈ 2 880 rows at the 60 s recording cadence) without a separate maintenance timer.
    public func recordAndPrune(
        cpuUsage: Double,
        ramUsedBytes: UInt64,
        ramPressureLevel: Int,
        diskUsedBytes: Int64
    ) {
        record(cpuUsage: cpuUsage, ramUsedBytes: ramUsedBytes, ramPressureLevel: ramPressureLevel, diskUsedBytes: diskUsedBytes)
        let now = Date()
        if lastPruneTime.map({ now.timeIntervalSince($0) >= 3600 }) ?? true {
            lastPruneTime = now
            purgeOldRawSamples()
        }
    }
    
    /// Cleans up raw samples older than 48 hours to keep the database size minimal.
    public func purgeOldRawSamples() {
        guard let db = connection.db else { return }
        let cutoff = Date().addingTimeInterval(-172800).timeIntervalSince1970
        let deleteSQL = "DELETE FROM telemetry_raw WHERE timestamp < ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, cutoff)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }
}
