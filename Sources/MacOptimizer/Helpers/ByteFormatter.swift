import Foundation

/// Utility for formatting bytes into human-readable strings (KB, MB, GB, TB)
public enum ByteFormatter: Sendable {
    
    public static func format(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    public static func formatMemory(_ bytes: UInt64) -> String {
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
    
    public static func formatShort(_ bytes: Int64) -> (value: String, unit: String) {
        let gigabytes = Double(bytes) / 1_073_741_824.0
        let megabytes = Double(bytes) / 1_048_576.0
        let kilobytes = Double(bytes) / 1024.0
        
        if gigabytes >= 1.0 {
            return (String(format: "%.1f", gigabytes), "GB")
        } else if megabytes >= 1.0 {
            return (String(format: "%.0f", megabytes), "MB")
        } else if kilobytes >= 1.0 {
            return (String(format: "%.0f", kilobytes), "KB")
        } else {
            return ("\(bytes)", "B")
        }
    }
}
