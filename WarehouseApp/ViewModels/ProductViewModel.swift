import Foundation
import Combine

class ProductViewModel: ObservableObject {
    @Published var products: [Product] = []

    private let defaultsKey = "wh_products_v2"

    init() { load() }

    // MARK: - Encrypted persistence

    private func load() {
        guard let encrypted = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded: [Product] = SecureStorage.decryptCodable(encrypted) else {
            // Fall back to legacy unencrypted data (one-time migration)
            migrateLegacyData()
            return
        }
        products = decoded
    }

    private func save() {
        guard let encrypted = SecureStorage.encryptCodable(products) else { return }
        UserDefaults.standard.set(encrypted, forKey: defaultsKey)
    }

    private func migrateLegacyData() {
        let legacyKey = "wh_products"
        guard let data = UserDefaults.standard.data(forKey: legacyKey),
              let decoded = try? JSONDecoder().decode([Product].self, from: data) else { return }
        products = decoded
        save()
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

    // MARK: - CRUD

    func find(barcode: String) -> Product? {
        products.first { $0.barcode == barcode }
    }

    func upsert(_ product: Product) {
        if let idx = products.firstIndex(where: { $0.id == product.id }) {
            products[idx] = product
        } else {
            products.append(product)
        }
        save()
    }

    func delete(_ product: Product) {
        products.removeAll { $0.id == product.id }
        save()
    }

    func addStock(barcode: String, qty: Int) {
        guard qty > 0, let idx = products.firstIndex(where: { $0.barcode == barcode }) else { return }
        products[idx].stock = min(products[idx].stock + qty, 99_999)
        save()
    }

    func removeStock(barcode: String, qty: Int) {
        guard qty > 0,
              let idx = products.firstIndex(where: { $0.barcode == barcode }),
              products[idx].stock >= qty else { return }
        products[idx].stock -= qty
        save()
    }

    // MARK: - Helpers

    var categories: [String] {
        Array(Set(products.map(\.category))).sorted()
    }

    var totalStockValue: Double {
        products.reduce(0) { $0 + $1.finalPrice * Double($1.stock) }
    }
}
