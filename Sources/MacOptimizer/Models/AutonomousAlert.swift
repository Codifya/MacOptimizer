import Foundation

/// Alert created by the autonomous background watchdog
public struct AutonomousAlert: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let message: String
    public let type: AlertType
    public let timestamp: Date
    public var isResolved: Bool
    public var autoHealed: Bool
    public let action: AIAction?
    
    public enum AlertType: String, Codable, Sendable, Equatable {
        case memorySpike = "Bellek Baskısı (RAM Spike)"
        case runawayProcess = "Kaçak / Donan İşlem (Runaway CPU)"
        case lowDisk = "Kritik Disk Alanı"
        case batteryDrain = "Aşırı Güç Tüketimi"
        case outdatedSecurity = "Güvenlik Güncellemesi"
        case routineMaintenance = "Rutin Otonom Bakım"
        
        public var iconName: String {
            switch self {
            case .memorySpike: return "memorychip.fill"
            case .runawayProcess: return "cpu.fill"
            case .lowDisk: return "internaldrive.fill"
            case .batteryDrain: return "battery.25"
            case .outdatedSecurity: return "shield.lefthalf.filled.trianglebadge.exclamationmark"
            case .routineMaintenance: return "sparkles"
            }
        }
        
        public var colorName: String {
            switch self {
            case .memorySpike: return "orange"
            case .runawayProcess: return "red"
            case .lowDisk: return "pink"
            case .batteryDrain: return "yellow"
            case .outdatedSecurity: return "purple"
            case .routineMaintenance: return "blue"
            }
        }
    }
    
    public init(
        id: UUID = UUID(),
        title: String,
        message: String,
        type: AlertType,
        timestamp: Date = Date(),
        isResolved: Bool = false,
        autoHealed: Bool = false,
        action: AIAction? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.type = type
        self.timestamp = timestamp
        self.isResolved = isResolved
        self.autoHealed = autoHealed
        self.action = action
    }
    
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }
}

/// Configuration settings for the autonomous watchdog and auto-healing engine
public struct AutonomousConfig: Codable, Sendable, Equatable {
    public var isWatchdogActive: Bool
    public var autoPurgeRAMOnSpike: Bool
    public var ramThresholdPercent: Double
    public var autoCleanTemporaryLogsWeekly: Bool
    public var notifyOnAnomalies: Bool
    public var scanIntervalSeconds: Double
    public var cpuRunawayThresholdPercent: Double
    
    public init(
        isWatchdogActive: Bool = true,
        autoPurgeRAMOnSpike: Bool = true,
        ramThresholdPercent: Double = 85.0,
        autoCleanTemporaryLogsWeekly: Bool = true,
        notifyOnAnomalies: Bool = true,
        scanIntervalSeconds: Double = 5.0,
        cpuRunawayThresholdPercent: Double = 90.0
    ) {
        self.isWatchdogActive = isWatchdogActive
        self.autoPurgeRAMOnSpike = autoPurgeRAMOnSpike
        self.ramThresholdPercent = ramThresholdPercent
        self.autoCleanTemporaryLogsWeekly = autoCleanTemporaryLogsWeekly
        self.notifyOnAnomalies = notifyOnAnomalies
        self.scanIntervalSeconds = scanIntervalSeconds
        self.cpuRunawayThresholdPercent = cpuRunawayThresholdPercent
    }
}
