import Foundation
import CryptoKit

struct Operador: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var pinHash: String
    var isActive: Bool = true
    var createdAt: Date = Date()

    static func hashPIN(_ pin: String) -> String {
        let digest = SHA256.hash(data: Data(pin.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func verifyPIN(_ pin: String) -> Bool {
        pinHash == Operador.hashPIN(pin)
    }
}
