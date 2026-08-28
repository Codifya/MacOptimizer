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
            sqlite3_finalize(stmt)
        }
    }
    
    /// Cleans up raw samples older than 24 hours to keep the database size minimal.
    public func purgeOldRawSamples() {
        guard let db = connection.db else { return }
        let cutoff = Date().addingTimeInterval(-86400).timeIntervalSince1970
        let deleteSQL = "DELETE FROM telemetry_raw WHERE timestamp < ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, cutoff)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }
}
