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

    static func isMercadoPagoQR(_ s: String) -> Bool {
        let lower = s.lowercased()
        return lower.contains("mercadopago") ||
               lower.hasPrefix("https://mpago") ||
               lower.hasPrefix("https://www.mercadopago")
    }

    static func classify(_ raw: String, products: [Product]) -> ScanResult {
        if let p = products.first(where: { $0.barcode == raw }) { return .product(p) }
        if isMercadoPagoQR(raw) { return .mercadoPagoQR(raw) }
        return .unknown(raw)
    }

    /// Sanitizes a price string: strips non-numeric/decimal chars, clamps to ≥ 0.
    static func sanitizedPrice(_ input: String) -> Double {
        let cleaned = input.filter { $0.isNumber || $0 == "." || $0 == "," }
            .replacingOccurrences(of: ",", with: ".")
        return max(0, Double(cleaned) ?? 0)
    }

    /// Sanitizes a stock/quantity string: clamps to ≥ 0.
    static func sanitizedStock(_ input: String) -> Int {
        max(0, Int(input.filter(\.isNumber)) ?? 0)
    }
}
