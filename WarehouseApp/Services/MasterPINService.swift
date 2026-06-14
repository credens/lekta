import Foundation
import Security
import CryptoKit

/// Stores the owner/master PIN hash in its own Keychain service so it is
/// never wiped by KeychainService.deleteAll() (e.g. when disconnecting MP).
enum MasterPINService {
    private static let service = "com.warehouseapp.master"
    private static let account = "master_pin_hash_v1"

    static var isSet: Bool { load() != nil }

    @discardableResult
    static func create(pin: String) -> Bool {
        guard pin.count == 4, pin.allSatisfy(\.isNumber) else { return false }
        return store(hash(pin))
    }

    static func verify(_ pin: String) -> Bool {
        guard let stored = load() else { return false }
        return stored == hash(pin)
    }

    // MARK: - Private

    private static func hash(_ pin: String) -> String {
        SHA256.hash(data: Data(pin.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    account,
            kSecReturnData:     true,
            kSecMatchLimit:     kSecMatchLimitOne,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private static func store(_ hashValue: String) -> Bool {
        guard let data = hashValue.data(using: .utf8) else { return false }
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    account,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData] = data
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }
}
