import Foundation

enum PaymentMethod: String, CaseIterable, Codable {
    case qrMP    = "QR MP"
    case pointMP = "Point MP"
    case cash    = "Efectivo"

    var icon: String {
        switch self {
        case .qrMP:    return "qrcode"
        case .pointMP: return "wave.3.right"
        case .cash:    return "banknote"
        }
    }
}
