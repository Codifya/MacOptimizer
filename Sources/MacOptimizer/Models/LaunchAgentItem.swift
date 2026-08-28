import Foundation

/// Type and location of startup item
public enum LaunchItemType: String, Sendable, Equatable {
    case userAgent = "Kullanıcı Servisi (~/Library/LaunchAgents)"
    case systemAgent = "Sistem Servisi (/Library/LaunchAgents)"
    case systemDaemon = "Sistem Arka Plan Servisi (/Library/LaunchDaemons)"
    case loginItem = "Giriş Öğesi (Login Item)"
}

/// Model representing a startup / launch agent on macOS
public struct LaunchAgentItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let path: String
    public let programArguments: [String]
    public var isEnabled: Bool
    public let runAtLoad: Bool
    public let itemType: LaunchItemType
    public let appName: String
    public let isProtected: Bool
    
    public init(
        id: String,
        label: String,
        path: String,
        programArguments: [String] = [],
        isEnabled: Bool = true,
        runAtLoad: Bool = true,
        itemType: LaunchItemType = .userAgent,
        appName: String = "",
        isProtected: Bool = false
    ) {
        self.id = id
        self.label = label
        self.path = path
        self.programArguments = programArguments
        self.isEnabled = isEnabled
        self.runAtLoad = runAtLoad
        self.itemType = itemType
        self.appName = appName
        self.isProtected = isProtected
    }
}
