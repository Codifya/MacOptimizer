import Foundation
import CryptoKit

/// Single file item in a duplicate group
public struct DuplicateItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let path: String
    public let name: String
    public let sizeBytes: Int64
    public let modificationDate: Date
    public var isSelectedForDeletion: Bool
    
    public var sizeFormatted: String {
        ByteFormatter.format(sizeBytes)
    }
}

/// A cluster of identical duplicate files sharing the same SHA-256 hash
public struct DuplicateFileGroup: Identifiable, Sendable, Equatable {
    public let id: String // SHA-256 Hash
    public let original: DuplicateItem
    public var duplicates: [DuplicateItem]
    public let sizePerFile: Int64
    
    public var totalWastedBytes: Int64 {
        let count = duplicates.filter { $0.isSelectedForDeletion }.count
        return Int64(count) * sizePerFile
    }
    
    public var formattedWastedSize: String {
        ByteFormatter.format(totalWastedBytes)
    }
}

/// High-speed duplicate file finder with three-phase size → partial-hash → SHA-256 indexing and
/// Zero-Harm Trash disposal.
///
/// All disk work runs through `runBlocking` (off the cooperative pool), checks cancellation between
/// files, and drains autorelease pools while enumerating. Hashing only reads whole files whose size
/// *and* first 64 KB both collide, which avoids reading most same-size-but-different files end to end.
public final class DuplicateFileFinderService: Sendable {
    public static let shared = DuplicateFileFinderService()
    
    /// Bytes hashed in the cheap pre-filter phase.
    static let partialHashBytes = 64 * 1024
    
    public init() {}
    
    /// Target scan directories
    public enum ScanTargetDirectory: String, CaseIterable, Identifiable, Sendable {
        case downloads = "İndirilenler"
        case documents = "Belgeler"
        case pictures = "Resimler"
        case desktop = "Masaüstü"
        
        public var id: String { rawValue }
        
        public func resolveURL() -> URL {
            let home = FileManager.default.homeDirectoryForCurrentUser
            switch self {
            case .downloads: return home.appendingPathComponent("Downloads")
            case .documents: return home.appendingPathComponent("Documents")
            case .pictures: return home.appendingPathComponent("Pictures")
            case .desktop: return home.appendingPathComponent("Desktop")
            }
        }
    }
    
    /// Scans specified directories for duplicate files. Returns partial (possibly empty) results when
    /// the calling task is cancelled.
    public func findDuplicates(
        in targets: [ScanTargetDirectory] = [.downloads, .documents],
        minSizeBytes: Int64 = 100 * 1024, // 100 KB minimum
        progressHandler: (@Sendable (String, Double) -> Void)? = nil
    ) async -> [DuplicateFileGroup] {
        let roots = targets.map { $0.resolveURL() }
        return await runBlocking { flag in
            Self.findDuplicatesSync(in: roots, minSizeBytes: minSizeBytes, flag: flag, progressHandler: progressHandler)
        }
    }
    
    /// Synchronous core, exposed for tests (roots may be any directories).
    static func findDuplicatesSync(
        in roots: [URL],
        minSizeBytes: Int64,
        flag: CancellationFlag,
        progressHandler: (@Sendable (String, Double) -> Void)?
    ) -> [DuplicateFileGroup] {
        let fileManager = FileManager.default
        progressHandler?("Dosyalar taranıyor ve boyutlar indeksleniyor...", 0.1)
        
        var sizeMap: [Int64: [URL]] = [:]
        
        // Phase 1: Rapid file discovery and size grouping
        for root in roots where !flag.isCancelled {
            guard fileManager.fileExists(atPath: root.path),
                  let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                  ) else { continue }
            
            var exhausted = false
            while !exhausted && !flag.isCancelled {
                autoreleasepool {
                    for _ in 0..<FileSizeCalculator.entriesPerPool {
                        guard let fileURL = enumerator.nextObject() as? URL else {
                            exhausted = true
                            return
                        }
                        guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                              values.isRegularFile == true,
                              let fileSize = values.fileSize,
                              fileSize >= minSizeBytes else {
                            continue
                        }
                        sizeMap[Int64(fileSize), default: []].append(fileURL)
                    }
                }
            }
        }
        
        // Filter candidate size groups with 2 or more files; release the rest immediately.
        let candidateGroups = sizeMap.filter { $0.value.count > 1 }
        sizeMap.removeAll()
        let totalCandidates = candidateGroups.values.reduce(0) { $0 + $1.count }
        guard totalCandidates > 0, !flag.isCancelled else {
            progressHandler?("Yinelenen dosya bulunamadı.", 1.0)
            return []
        }
        
        var processedCount = 0
        var hashMap: [String: [(url: URL, size: Int64, date: Date)]] = [:]
        
        for (size, files) in candidateGroups where !flag.isCancelled {
            // Phase 2: cheap pre-filter on the first 64 KB (whole file when smaller).
            var partialGroups: [String: [URL]] = [:]
            for fileURL in files where !flag.isCancelled {
                if let partial = computeSHA256(for: fileURL, maxBytes: partialHashBytes, flag: flag) {
                    partialGroups[partial, default: []].append(fileURL)
                }
            }
            
            // Phase 3: full SHA-256 only where the prefix also collides.
            for (partialHash, group) in partialGroups where group.count > 1 && !flag.isCancelled {
                for fileURL in group where !flag.isCancelled {
                    processedCount += 1
                    let progress = 0.1 + (0.8 * Double(processedCount) / Double(totalCandidates))
                    progressHandler?("SHA-256 hesaplanıyor: \(fileURL.lastPathComponent)", progress)
                    
                    // A file no larger than the prefix is already fully hashed.
                    let fullHash = size <= Int64(partialHashBytes)
                        ? partialHash
                        : computeSHA256(for: fileURL, maxBytes: nil, flag: flag)
                    if let hash = fullHash {
                        let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
                        hashMap[hash, default: []].append((url: fileURL, size: size, date: modDate))
                    }
                }
            }
        }
        
        if flag.isCancelled { return [] }
        
        // Phase 4: Build DuplicateFileGroup results
        var resultGroups: [DuplicateFileGroup] = []
        for (hash, fileEntries) in hashMap where fileEntries.count > 1 {
            // Sort by modification date: oldest is original, newer ones are marked for deletion
            let sortedEntries = fileEntries.sorted { $0.date < $1.date }
            let originalEntry = sortedEntries[0]
            
            let originalItem = DuplicateItem(
                id: originalEntry.url.path,
                path: originalEntry.url.path,
                name: originalEntry.url.lastPathComponent,
                sizeBytes: originalEntry.size,
                modificationDate: originalEntry.date,
                isSelectedForDeletion: false
            )
            
            let duplicateItems = sortedEntries.dropFirst().map { entry in
                DuplicateItem(
                    id: entry.url.path,
                    path: entry.url.path,
                    name: entry.url.lastPathComponent,
                    sizeBytes: entry.size,
                    modificationDate: entry.date,
                    isSelectedForDeletion: true
                )
            }
            
            resultGroups.append(DuplicateFileGroup(
                id: hash,
                original: originalItem,
                duplicates: duplicateItems,
                sizePerFile: originalEntry.size
            ))
        }
        
        progressHandler?("Tarama Tamamlandı", 1.0)
        return resultGroups.sorted { $0.totalWastedBytes > $1.totalWastedBytes }
    }
    
    /// Streaming SHA-256 over 1 MB chunks (constant memory), optionally limited to the first `maxBytes`.
    static func computeSHA256(for fileURL: URL, maxBytes: Int?, flag: CancellationFlag) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? handle.close() }
        
        var hasher = SHA256()
        let chunkSize = 1024 * 1024 // 1 MB chunk
        var remaining = maxBytes ?? Int.max
        
        while remaining > 0, !flag.isCancelled, autoreleasepool(invoking: {
            let data = handle.readData(ofLength: min(chunkSize, remaining))
            if data.isEmpty {
                return false
            }
            remaining -= data.count
            hasher.update(data: data)
            return true
        }) {}
        
        if flag.isCancelled { return nil }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// Safely cleans selected duplicate files by moving them to .Trash
    public func cleanDuplicates(_ groups: [DuplicateFileGroup]) async -> (freedBytes: Int64, deletedCount: Int, failedCount: Int) {
        await runBlocking(qos: .userInitiated) { _ in Self.cleanDuplicatesSync(groups) }
    }
    
    private static func cleanDuplicatesSync(_ groups: [DuplicateFileGroup]) -> (freedBytes: Int64, deletedCount: Int, failedCount: Int) {
        var totalFreed: Int64 = 0
        var deleted = 0
        var failed = 0
        
        for group in groups {
            for dup in group.duplicates where dup.isSelectedForDeletion {
                let url = URL(fileURLWithPath: dup.path)
                do {
                    let result = try SafeOperationExecutor.removeFile(at: url, moveToTrash: true)
                    if result.success {
                        totalFreed += dup.sizeBytes
                        deleted += 1
                    } else {
                        failed += 1
                    }
                } catch {
                    failed += 1
                }
            }
        }
        
        return (totalFreed, deleted, failed)
    }
}
