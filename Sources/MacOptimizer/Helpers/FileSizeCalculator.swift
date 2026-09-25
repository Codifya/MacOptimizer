import Foundation

/// Stateless, thread-safe recursive size calculation shared by the junk cleaner, app scanner and
/// uninstaller.
///
/// Previously this lived on the `JunkCleanerService` actor, so the app scanner and uninstaller
/// had to hop onto that actor and queued behind any junk scan in progress. Call it from blocking
/// contexts only (`runBlocking`), never from the main actor.
public enum FileSizeCalculator {
    /// Number of directory entries processed per autorelease pool drain. Enumerating on a background
    /// thread with no pool makes every `NSURL`/resource-value dictionary live until the thread's pool
    /// drains, which inflated memory by hundreds of MB while walking large caches.
    static let entriesPerPool = 256

    public static func size(of url: URL, cancellation: CancellationFlag? = nil) -> Int64 {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else { return 0 }

        var totalSize: Int64 = 0
        var exhausted = false
        while !exhausted {
            if cancellation?.isCancelled == true { break }
            autoreleasepool {
                for _ in 0..<entriesPerPool {
                    guard let fileURL = enumerator.nextObject() as? URL else {
                        exhausted = true
                        return
                    }
                    if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                       values.isRegularFile == true,
                       let fileSize = values.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
        }
        return totalSize
    }

    /// Async convenience that performs the walk off the cooperative pool and honours task cancellation.
    public static func measure(_ url: URL) async -> Int64 {
        await runBlocking { flag in size(of: url, cancellation: flag) }
    }
}
