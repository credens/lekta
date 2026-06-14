import Foundation
import Combine

class ProductViewModel: ObservableObject {
    @Published var products: [Product] = []

    private let key = "wh_products"

    init() {
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Product].self, from: data) else { return }
        products = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(products) else { return }
        UserDefaults.standard.set(data, forKey: key)
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
        guard let idx = products.firstIndex(where: { $0.barcode == barcode }) else { return }
        products[idx].stock += qty
        save()
    }

    func removeStock(barcode: String, qty: Int) {
        guard let idx = products.firstIndex(where: { $0.barcode == barcode }),
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
