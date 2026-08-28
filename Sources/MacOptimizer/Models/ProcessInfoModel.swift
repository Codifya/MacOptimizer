import Foundation
import AppKit

/// Model representing a running process on macOS
public struct ProcessInfoModel: Identifiable, Sendable, Equatable {
    public let id: Int32 // PID
    public let pid: Int32
    public let name: String
    public let path: String
    public let memoryBytes: UInt64
    public let cpuPercentage: Double
    public let isUserApp: Bool
    public let bundleIdentifier: String?
    public let isProtected: Bool
    
    public init(
        pid: Int32,
        name: String,
        path: String = "",
        memoryBytes: UInt64 = 0,
        cpuPercentage: Double = 0.0,
        isUserApp: Bool = false,
        bundleIdentifier: String? = nil,
        isProtected: Bool = false
    ) {
        self.id = pid
        self.pid = pid
        self.name = name
        self.path = path
        self.memoryBytes = memoryBytes
        self.cpuPercentage = cpuPercentage
        self.isUserApp = isUserApp
        self.bundleIdentifier = bundleIdentifier
        self.isProtected = isProtected
    }
    
    public var memoryFormatted: String {
        ByteFormatter.formatMemory(memoryBytes)
    }
    
    public var cpuFormatted: String {
        String(format: "%.1f%%", cpuPercentage)
    }
}
