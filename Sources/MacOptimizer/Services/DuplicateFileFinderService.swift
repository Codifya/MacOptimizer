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

/// High-speed duplicate file finder with two-phase size-hash indexing and Zero-Harm Trash disposal.
public actor DuplicateFileFinderService {
    public static let shared = DuplicateFileFinderService()
    
    private let fileManager = FileManager.default
    private let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    
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
    
    /// Scans specified directories for duplicate files
    public func findDuplicates(
        in targets: [ScanTargetDirectory] = [.downloads, .documents],
        minSizeBytes: Int64 = 100 * 1024, // 100 KB minimum
        progressHandler: (@Sendable (String, Double) -> Void)? = nil
    ) async -> [DuplicateFileGroup] {
        progressHandler?("Dosyalar taranıyor ve boyutlar indeksleniyor...", 0.1)
        
        var sizeMap: [Int64: [URL]] = [:]
        
        // Phase 1: Rapid file discovery and size grouping
        for target in targets {
            let targetURL = target.resolveURL()
            guard fileManager.fileExists(atPath: targetURL.path) else { continue }
            
            if let enumerator = fileManager.enumerator(
                at: targetURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                while let fileURL = enumerator.nextObject() as? URL {
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                          resourceValues.isRegularFile == true,
                          let fileSize = resourceValues.fileSize,
                          fileSize >= minSizeBytes else {
                        continue
                    }
                    
                    sizeMap[Int64(fileSize), default: []].append(fileURL)
                }
            }
        }
        
        // Filter candidate size groups with 2 or more files
        let candidateGroups = sizeMap.filter { $0.value.count > 1 }
        let totalCandidates = candidateGroups.values.reduce(0) { $0 + $1.count }
        guard totalCandidates > 0 else {
            progressHandler?("Yinelenen dosya bulunamadı.", 1.0)
            return []
        }
        
        // Phase 2: Compute cryptographic SHA-256 for candidate files
        var hashMap: [String: [(url: URL, size: Int64, date: Date)]] = [:]
        var processedCount = 0
        
        for (size, files) in candidateGroups {
            for fileURL in files {
                processedCount += 1
                let progress = 0.1 + (0.8 * Double(processedCount) / Double(totalCandidates))
                progressHandler?("SHA-256 hesaplanıyor: \(fileURL.lastPathComponent)", progress)
                
                if let hash = computeSHA256(for: fileURL) {
                    let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
                    hashMap[hash, default: []].append((url: fileURL, size: size, date: modDate))
                }
            }
        }
        
        // Phase 3: Build DuplicateFileGroup results
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
    
    /// Computes SHA-256 hash using chunked streaming
    private func computeSHA256(for fileURL: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? handle.close() }
        
        var hasher = SHA256()
        let chunkSize = 1024 * 1024 // 1 MB chunk
        
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: chunkSize)
            if data.isEmpty {
                return false
            }
            hasher.update(data: data)
            return true
        }) {}
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// Safely cleans selected duplicate files by moving them to .Trash
    public func cleanDuplicates(_ groups: [DuplicateFileGroup]) async -> (freedBytes: Int64, deletedCount: Int, failedCount: Int) {
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
