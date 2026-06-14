import Foundation

struct Product: Identifiable, Codable {
    var id: UUID = UUID()
    var barcode: String
    var name: String
    var price: Double
    var stock: Int
    var variants: [Variant]
    var discount: Double         // 0.0–1.0
    var category: String

    struct Variant: Identifiable, Codable {
        var id: UUID = UUID()
        var name: String         // "Color", "Talle"
        var value: String        // "Rojo", "XL"
        var priceDelta: Double
        var stock: Int
    }

    var finalPrice: Double { price * (1 - discount) }
}
