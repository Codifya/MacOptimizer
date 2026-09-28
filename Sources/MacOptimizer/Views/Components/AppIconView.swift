import SwiftUI
import AppKit

/// Bounded application-icon cache.
///
/// Rows previously called `NSWorkspace.shared.icon(forFile:)` inside `body`, i.e. on every render of
/// every row (each call resolves the bundle's icon through IconServices and returns a fresh
/// multi-representation `NSImage`). `NSCache` evicts under memory pressure and the count limit
/// keeps the worst case bounded even without pressure.
@MainActor
enum AppIconCache {
    static let countLimit = 256

    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = countLimit
        return cache
    }()

    static func icon(forPath path: String) -> NSImage {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: path)
        // Render at the largest size we display; avoids retaining huge representations for layout.
        icon.size = NSSize(width: 64, height: 64)
        cache.setObject(icon, forKey: key)
        return icon
    }
}

/// Cached application icon for list rows and sheets.
struct AppIconView: View {
    let path: String

    var body: some View {
        Image(nsImage: AppIconCache.icon(forPath: path))
            .resizable()
            .scaledToFit()
    }
}
