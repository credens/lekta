import Foundation

struct BarcodeService {

    /// Validates EAN-13 format AND checksum digit.
    static func isEAN13(_ s: String) -> Bool {
        guard s.count == 13, s.allSatisfy(\.isNumber) else { return false }
        let digits = s.compactMap { $0.wholeNumberValue }
        let sum = digits.dropLast().enumerated().reduce(0) { acc, pair in
            acc + pair.element * (pair.offset.isMultiple(of: 2) ? 1 : 3)
        }
        let check = (10 - (sum % 10)) % 10
        return check == digits[12]
    }

    /// Detects MercadoPago QR codes using proper URL host matching.
    static func isMercadoPagoQR(_ s: String) -> Bool {
        guard let url = URL(string: s), let host = url.host?.lowercased() else { return false }
        let mpHosts = ["mercadopago.com", "mercadopago.com.ar", "mercadopago.com.mx",
                       "mercadopago.com.co", "mercadopago.com.br", "mpago.la"]
        return mpHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }

    static func classify(_ raw: String, products: [Product]) -> ScanResult {
        if let p = products.first(where: { $0.barcode == raw }) { return .product(p) }
        if isMercadoPagoQR(raw) { return .mercadoPagoQR(raw) }
        return .unknown(raw)
    }

    /// Sanitizes a price string: strips non-numeric/decimal chars, clamps 0–9_999_999.
    static func sanitizedPrice(_ input: String) -> Double {
        let cleaned = input.filter { $0.isNumber || $0 == "." || $0 == "," }
            .replacingOccurrences(of: ",", with: ".")
        return min(9_999_999, max(0, Double(cleaned) ?? 0))
    }

    /// Sanitizes a stock/quantity string: clamps 0–99_999.
    static func sanitizedStock(_ input: String) -> Int {
        min(99_999, max(0, Int(input.filter(\.isNumber)) ?? 0))
    }
}
