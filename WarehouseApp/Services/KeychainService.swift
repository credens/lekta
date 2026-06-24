import Foundation
import Security

enum KeychainService {
    private static let service = "com.warehouseapp"

    enum Key: String, CaseIterable {
        case mpAccountId    = "mp_account_id"
        case mpAccessToken  = "mp_access_token"
        case mpRefreshToken = "mp_refresh_token"
        case mpUserId       = "mp_user_id"
        case mpExpiresAt    = "mp_expires_at"
        case skipMPAuth     = "skip_mp_auth"
        case backendAccessToken = "backend_access_token"
        case backendAccessTokenExpiresAt = "backend_access_token_expires_at"
        case backendRefreshToken = "backend_refresh_token"
        case backendRefreshTokenExpiresAt = "backend_refresh_token_expires_at"
        case backendBusinessId = "backend_business_id"
        case backendDeviceId = "backend_device_id"
    }

    // MARK: - Write

    @discardableResult
    static func set(_ value: String, for key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    key.rawValue,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData] = data
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Read

    static func get(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    key.rawValue,
            kSecReturnData:     true,
            kSecMatchLimit:     kSecMatchLimitOne,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
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

    static var hasMPToken: Bool { return get(.mpAccessToken) != nil }
    static var hasMPConnection: Bool { return get(.mpAccountId) != nil || hasMPToken }
    static var mpAccountId: String? { return get(.mpAccountId) }
    static var mpAccessToken: String? { return get(.mpAccessToken) }

    static var skipMPAuth: Bool {
        get { get(.skipMPAuth) == "1" }
        set { if newValue { set("1", for: .skipMPAuth) } else { delete(.skipMPAuth) } }
    }
}
