import Foundation

/// Record of an optimization or cleaning action
public struct OptimizationReport: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let title: String
    public let freedMemoryBytes: UInt64
    public let freedDiskBytes: Int64
    public let details: [String]
    public let durationSeconds: Double
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        title: String,
        freedMemoryBytes: UInt64 = 0,
        freedDiskBytes: Int64 = 0,
        details: [String] = [],
        durationSeconds: Double = 0.0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.freedMemoryBytes = freedMemoryBytes
        self.freedDiskBytes = freedDiskBytes
        self.details = details
        self.durationSeconds = durationSeconds
    }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    public var freedMemoryFormatted: String {
        ByteFormatter.formatMemory(freedMemoryBytes)
    }
    
    public var freedDiskFormatted: String {
        ByteFormatter.format(freedDiskBytes)
    }
}
