import Foundation

/// Categories of cleanable junk and unnecessary files
public enum JunkCategoryType: String, CaseIterable, Identifiable, Sendable {
    case systemCache = "systemCache"
    case systemLogs = "systemLogs"
    case developerCache = "developerCache"
    case browserCache = "browserCache"
    case trashBin = "trashBin"
    case largeFiles = "largeFiles"
    case appLeftovers = "appLeftovers"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .systemCache: return L10n.string("System and App Cache", table: .services)
        case .systemLogs: return L10n.string("System and Error Logs", table: .services)
        case .developerCache: return L10n.string("Developer & Build Leftovers", table: .services)
        case .browserCache: return L10n.string("Browser Caches", table: .services)
        case .trashBin: return L10n.string("Trash", table: .services)
        case .largeFiles: return L10n.string("Large and Old Files", table: .services)
        case .appLeftovers: return L10n.string("Removed App Leftovers", table: .services)
        }
    }
    
    public var description: String {
        switch self {
        case .systemCache: return L10n.string("Temporary cache files created by apps and macOS.", table: .services)
        case .systemLogs: return L10n.string("Old system crash reports, error logs, and diagnostic files.", table: .services)
        case .developerCache: return L10n.string("Xcode DerivedData, Archives, DeviceSupport, Node/NPM, CocoaPods, and Cargo caches.", table: .services)
        case .browserCache: return L10n.string("Web caches of the Safari, Chrome, Arc, Firefox, and Edge browsers.", table: .services)
        case .trashBin: return L10n.string("Deleted files waiting in the user's Trash.", table: .services)
        case .largeFiles: return L10n.string("Large files (>100 MB) taking up space in Downloads and Documents.", table: .services)
        case .appLeftovers: return L10n.string("Leftover folders and settings files from deleted apps.", table: .services)
        }
    }
    
    public var iconName: String {
        switch self {
        case .systemCache: return "archivebox.fill"
        case .systemLogs: return "doc.text.magnifyingglass"
        case .developerCache: return "hammer.fill"
        case .browserCache: return "globe"
        case .trashBin: return "trash.fill"
        case .largeFiles: return "folder.badge.gearshape"
        case .appLeftovers: return "square.stack.3d.down.right.fill"
        }
    }
    
    public var tintColorName: String {
        switch self {
        case .systemCache: return "blue"
        case .systemLogs: return "orange"
        case .developerCache: return "purple"
        case .browserCache: return "teal"
        case .trashBin: return "red"
        case .largeFiles: return "indigo"
        case .appLeftovers: return "pink"
        }
    }
    
    public var isSafeToAutoClean: Bool {
        switch self {
        case .systemCache, .systemLogs, .browserCache:
            return true
        default:
            return false
        }
    }
}

/// An individual file or directory identified as cleanable junk
public struct JunkFileItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let path: String
    public let name: String
    public let sizeBytes: Int64
    public let category: JunkCategoryType
    public var isSelected: Bool
    public let detail: String
    public let lastModifiedDate: Date?
    
    public init(
        path: String,
        name: String,
        sizeBytes: Int64,
        category: JunkCategoryType,
        isSelected: Bool = true,
        detail: String = "",
        lastModifiedDate: Date? = nil
    ) {
        self.id = path
        self.path = path
        self.name = name
        self.sizeBytes = sizeBytes
        self.category = category
        self.isSelected = isSelected
        self.detail = detail
        self.lastModifiedDate = lastModifiedDate
    }
    
    public var sizeFormatted: String {
        ByteFormatter.format(sizeBytes)
    }
}

/// A group of junk files under a single category
public struct JunkCategoryGroup: Identifiable, Sendable, Equatable {
    public let id: JunkCategoryType
    public let type: JunkCategoryType
    public var items: [JunkFileItem]
    public var isExpanded: Bool
    
    public init(type: JunkCategoryType, items: [JunkFileItem] = [], isExpanded: Bool = false) {
        self.id = type
        self.type = type
        self.items = items
        self.isExpanded = isExpanded
    }
    
    public var totalSizeBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var selectedSizeBytes: Int64 {
        items.filter { $0.isSelected }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var isAllSelected: Bool {
        !items.isEmpty && items.allSatisfy { $0.isSelected }
    }
    
    public var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }
    
    public var totalFormatted: String {
        ByteFormatter.format(totalSizeBytes)
    }
    
    public var selectedFormatted: String {
        ByteFormatter.format(selectedSizeBytes)
    }
}
