import Foundation
import Security

/// Secure secrets and API key manager using the native macOS Keychain.
public struct KeychainManager: Sendable {
    public static let defaultService = "com.osmancagrigenc.MacOptimizer"
    
    /// Saves a secret string into the macOS Keychain.
    @discardableResult
    public static func saveSecret(key: String, value: String, service: String = defaultService) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete existing item first to update
        deleteSecret(key: key, service: service)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Loads a secret string from the macOS Keychain.
    public static func loadSecret(key: String, service: String = defaultService) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    /// Deletes a secret from the macOS Keychain.
    @discardableResult
    public static func deleteSecret(key: String, service: String = defaultService) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Migrates any legacy plain-text keys from UserDefaults into Keychain.
    public static func migrateLegacySecretsIfNeeded() {
        let userDefaultsKey = "nim_api_key_v1"
        if let legacyKey = UserDefaults.standard.string(forKey: userDefaultsKey), !legacyKey.isEmpty {
            _ = saveSecret(key: "nim_api_key", value: legacyKey)
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }
}
