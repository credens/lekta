import Foundation

enum ScanResult {
    case product(Product)
    case mercadoPagoQR(String)
    case unknown(String)
}
