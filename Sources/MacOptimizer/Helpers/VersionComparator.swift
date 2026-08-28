import Foundation

/// Compares software version strings according to semantic versioning and macOS version conventions.
public enum VersionComparator {
    
    /// Returns true if `remoteVersion` is newer than `currentVersion`.
    public static func isNewer(remoteVersion: String, than currentVersion: String) -> Bool {
        let cleanRemote = clean(remoteVersion)
        let cleanCurrent = clean(currentVersion)
        
        if cleanRemote == cleanCurrent {
            return false
        }
        
        return compare(cleanRemote, cleanCurrent) == .orderedDescending
    }
    
    /// Cleans version strings by stripping prefixes like "v" or "v.", trailing hashes, etc.
    public static func clean(_ version: String) -> String {
        var str = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("v") || str.hasPrefix("V") {
            str.removeFirst()
        }
        return str
    }
    
    /// Compares two version strings component by component.
    public static func compare(_ v1: String, _ v2: String) -> ComparisonResult {
        let parts1 = v1.components(separatedBy: CharacterSet(charactersIn: ".-_"))
        let parts2 = v2.components(separatedBy: CharacterSet(charactersIn: ".-_"))
        
        let maxCount = max(parts1.count, parts2.count)
        
        for i in 0..<maxCount {
            let part1 = i < parts1.count ? parts1[i] : "0"
            let part2 = i < parts2.count ? parts2[i] : "0"
            
            if let num1 = Int(part1), let num2 = Int(part2) {
                if num1 < num2 {
                    return .orderedAscending
                } else if num1 > num2 {
                    return .orderedDescending
                }
            } else {
                let comp = part1.compare(part2, options: .numeric)
                if comp != .orderedSame {
                    return comp
                }
            }
        }
        
        return .orderedSame
    }
}
