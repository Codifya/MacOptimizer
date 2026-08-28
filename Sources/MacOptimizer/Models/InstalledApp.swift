import Foundation
import AppKit

/// Architecture type of a compiled macOS application binary
public enum AppArchitecture: String, Sendable, Equatable {
    case universal = "Universal (Apple Silicon + Intel)"
    case appleSilicon = "Apple Silicon (Native arm64)"
    case intel = "Intel (x86_64)"
    case unknown = "Bilinmeyen"
    
    public var shortName: String {
        switch self {
        case .universal: return "Universal"
        case .appleSilicon: return "Apple Silicon"
        case .intel: return "Intel"
        case .unknown: return "Diğer"
        }
    }
    
    public var badgeColor: String {
        switch self {
        case .universal: return "green"
        case .appleSilicon: return "blue"
        case .intel: return "orange"
        case .unknown: return "gray"
        }
    }
}

/// Software update metadata
public struct AppUpdateInfo: Sendable, Equatable {
    public var hasUpdate: Bool
    public var latestVersion: String
    public var downloadURL: String
    public var releaseNotesURL: String
    public var releaseNotes: String
    public var updateSource: UpdateSource
    public var isChecking: Bool
    public var checkError: String?
    
    public enum UpdateSource: String, Sendable, Equatable {
        case sparkle = "Sparkle Feed"
        case homebrew = "Homebrew Cask"
        case appStore = "Mac App Store"
        case directCheck = "Doğrudan Kontrol"
    }
    
    public init(
        hasUpdate: Bool = false,
        latestVersion: String = "",
        downloadURL: String = "",
        releaseNotesURL: String = "",
        releaseNotes: String = "",
        updateSource: UpdateSource = .sparkle,
        isChecking: Bool = false,
        checkError: String? = nil
    ) {
        self.hasUpdate = hasUpdate
        self.latestVersion = latestVersion
        self.downloadURL = downloadURL
        self.releaseNotesURL = releaseNotesURL
        self.releaseNotes = releaseNotes
        self.updateSource = updateSource
        self.isChecking = isChecking
        self.checkError = checkError
    }
}

/// Model representing an installed macOS application
public struct InstalledApp: Identifiable, Sendable, Equatable {
    public let id: String // path or bundle ID
    public let name: String
    public let bundleIdentifier: String
    public let path: String
    public let version: String
    public let buildNumber: String
    public let minOSVersion: String
    public let architecture: AppArchitecture
    public var sizeBytes: Int64
    public let isSystemApp: Bool
    public let lastModifiedDate: Date?
    public var updateInfo: AppUpdateInfo
    public var associatedFilePaths: [String]
    
    public init(
        name: String,
        bundleIdentifier: String,
        path: String,
        version: String = "1.0",
        buildNumber: String = "1",
        minOSVersion: String = "",
        architecture: AppArchitecture = .universal,
        sizeBytes: Int64 = 0,
        isSystemApp: Bool = false,
        lastModifiedDate: Date? = nil,
        updateInfo: AppUpdateInfo = AppUpdateInfo(),
        associatedFilePaths: [String] = []
    ) {
        self.id = path
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.version = version
        self.buildNumber = buildNumber
        self.minOSVersion = minOSVersion
        self.architecture = architecture
        self.sizeBytes = sizeBytes
        self.isSystemApp = isSystemApp
        self.lastModifiedDate = lastModifiedDate
        self.updateInfo = updateInfo
        self.associatedFilePaths = associatedFilePaths
    }
    
    public var sizeFormatted: String {
        ByteFormatter.format(sizeBytes)
    }
}
