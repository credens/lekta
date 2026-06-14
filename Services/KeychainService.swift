import Foundation
import Security

enum KeychainService {
    private static let service = "com.warehouseapp"

    enum Key: String, CaseIterable {
        case mpAccessToken  = "mp_access_token"
        case mpRefreshToken = "mp_refresh_token"
        case mpUserId       = "mp_user_id"
        case mpExpiresAt    = "mp_expires_at"
    }

    // MARK: - Write

    @discardableResult
    static func set(_ value: String, for key: Key) -> Bool {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData] = data
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Read

    static func get(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    @discardableResult
    static func delete(_ key: Key) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    static func deleteAll() {
        Key.allCases.forEach { delete($0) }
    }

    // MARK: - Convenience

    static var hasMPToken: Bool {
        get(.mpAccessToken) != nil
    }

    static var mpAccessToken: String? {
        get(.mpAccessToken)
    }
}
