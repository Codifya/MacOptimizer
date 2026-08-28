import Foundation

/// Detailed memory usage statistics
public struct MemoryStats: Sendable, Equatable {
    public var totalBytes: UInt64 = 0
    public var freeBytes: UInt64 = 0
    public var activeBytes: UInt64 = 0
    public var inactiveBytes: UInt64 = 0
    public var wiredBytes: UInt64 = 0
    public var compressedBytes: UInt64 = 0
    public var appMemoryBytes: UInt64 = 0
    public var memoryPressure: Double = 0.0 // 0.0 to 1.0
    public var pressureLevel: MemoryPressureLevel = .normal
    
    public enum MemoryPressureLevel: String, Sendable, Equatable {
        case normal = "Normal"
        case warning = "Uyarı"
        case critical = "Kritik"
        
        public var colorName: String {
            switch self {
            case .normal: return "green"
            case .warning: return "orange"
            case .critical: return "red"
            }
        }
    }
    
    public var usedBytes: UInt64 {
        return totalBytes > freeBytes ? (totalBytes - freeBytes - inactiveBytes) : 0
    }
    
    public var actualUsedBytes: UInt64 {
        return activeBytes + wiredBytes + compressedBytes
    }
    
    public var freeAndInactiveBytes: UInt64 {
        return freeBytes + inactiveBytes
    }
    
    public var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(actualUsedBytes) / Double(totalBytes)
    }
    
    public var freePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(freeAndInactiveBytes) / Double(totalBytes)
    }
}

/// CPU usage statistics
public struct CPUStats: Sendable, Equatable {
    public var systemUsage: Double = 0.0 // 0.0 - 100.0
    public var userUsage: Double = 0.0   // 0.0 - 100.0
    public var idleUsage: Double = 100.0 // 0.0 - 100.0
    public var totalUsage: Double = 0.0  // 0.0 - 100.0
    public var physicalCores: Int = 0
    public var logicalCores: Int = 0
    public var processorName: String = ""
}

/// Disk volume storage statistics
public struct DiskStats: Sendable, Equatable {
    public var totalBytes: Int64 = 0
    public var freeBytes: Int64 = 0
    public var usedBytes: Int64 = 0
    public var purgeableBytes: Int64 = 0
    public var volumeName: String = "Macintosh HD"
    
    public var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    public var freePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(freeBytes) / Double(totalBytes)
    }
}

/// Battery & Power statistics
public struct BatteryStats: Sendable, Equatable {
    public var isPresent: Bool = false
    public var isCharging: Bool = false
    public var isCharged: Bool = false
    public var percentage: Int = 100
    public var cycleCount: Int = 0
    public var healthPercentage: Int = 100
    public var condition: String = "Normal"
    public var timeRemainingFormatted: String = ""
    public var powerSource: String = "AC Gücü"
}

/// General Hardware information
public struct HardwareInfo: Sendable, Equatable {
    public var modelName: String = "Mac"
    public var chipName: String = "Apple Silicon"
    public var osVersion: String = ""
    public var buildVersion: String = ""
    public var uptimeString: String = ""
    public var serialNumber: String = ""
    public var memorySizeFormatted: String = ""
}
