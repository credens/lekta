import Foundation
import CryptoKit
import Security

enum SecureStorage {
    private static let service = "com.warehouseapp.storage"
    private static let keyAccount = "storage_encryption_key_v1"

    // MARK: - Key lifecycle

    private static func loadKeyData() -> Data? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      keyAccount,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
            kSecAttrAccessible:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return data
    }

    private static func createAndStoreKey() -> Data? {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return nil }
        let keyData = Data(bytes)
        let attrs: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    keyAccount,
            kSecValueData:      keyData,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(attrs as CFDictionary, nil)
        return keyData
    }

    private static func symmetricKey() -> SymmetricKey? {
        guard let data = loadKeyData() ?? createAndStoreKey() else { return nil }
        return SymmetricKey(data: data)
    }

    // MARK: - Encrypt / Decrypt

    static func encrypt(_ data: Data) -> Data? {
        guard let key = symmetricKey(),
              let sealed = try? AES.GCM.seal(data, using: key) else { return nil }
        return sealed.combined
    }

    static func decrypt(_ data: Data) -> Data? {
        guard let key = symmetricKey(),
              let box = try? AES.GCM.SealedBox(combined: data),
              let plain = try? AES.GCM.open(box, using: key) else { return nil }
        return plain
    }

    // MARK: - Codable helpers

    static func encryptCodable<T: Encodable>(_ value: T) -> Data? {
        guard let json = try? JSONEncoder().encode(value) else { return nil }
        return encrypt(json)
    }

    static func decryptCodable<T: Decodable>(_ data: Data, as type: T.Type = T.self) -> T? {
        guard let plain = decrypt(data) else { return nil }
        return try? JSONDecoder().decode(type, from: plain)
    }
}
