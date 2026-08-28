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
        case .systemCache: return "Sistem ve Uygulama Önbelleği"
        case .systemLogs: return "Sistem ve Hata Günlükleri"
        case .developerCache: return "Geliştirici & Build Kalıntıları"
        case .browserCache: return "Tarayıcı Önbellekleri"
        case .trashBin: return "Çöp Sepeti"
        case .largeFiles: return "Büyük ve Eski Dosyalar"
        case .appLeftovers: return "Kaldırılmış Uygulama Kalıntıları"
        }
    }
    
    public var description: String {
        switch self {
        case .systemCache: return "Uygulamalar ve macOS tarafından oluşturulan geçici önbellek dosyaları."
        case .systemLogs: return "Eski sistem çökme raporları, hata logları ve tanı dosyaları."
        case .developerCache: return "Xcode DerivedData, Archives, DeviceSupport, Node/NPM, CocoaPods ve Cargo önbellekleri."
        case .browserCache: return "Safari, Chrome, Arc, Firefox ve Edge tarayıcılarının web önbellekleri."
        case .trashBin: return "Kullanıcı çöp kutusunda bekleyen silinmiş dosyalar."
        case .largeFiles: return "İndirilenler ve Belgeler'de yer kaplayan büyük boyutlu dosyalar (>100 MB)."
        case .appLeftovers: return "Silinmiş uygulamalardan geriye kalan artık klasör ve ayar dosyaları."
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
