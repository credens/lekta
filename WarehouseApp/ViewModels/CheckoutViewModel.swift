import Foundation
import Combine

struct CartItem: Identifiable {
    var id: UUID = UUID()
    var product: Product
    var quantity: Int
    var subtotal: Double { product.finalPrice * Double(quantity) }
}

class CheckoutViewModel: ObservableObject {
    @Published var items: [CartItem] = []

    // MARK: - Cart operations

    func add(product: Product) {
        if let idx = items.firstIndex(where: { $0.product.id == product.id }) {
            items[idx].quantity += 1
        } else {
            items.append(CartItem(product: product, quantity: 1))
        }
    }

    func remove(item: CartItem) {
        items.removeAll { $0.id == item.id }
    }

    func updateQty(item: CartItem, qty: Int) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        if qty <= 0 {
            items.remove(at: idx)
        } else {
            items[idx].quantity = qty
        }
    }

    func clear() {
        items = []
    }

    // MARK: - Totals

    var subtotalBeforeDiscount: Double {
        items.reduce(0) { $0 + $1.product.price * Double($1.quantity) }
    }

    var discount: Double {
        subtotalBeforeDiscount - total
    }

    var total: Double {
        items.reduce(0) { $0 + $1.subtotal }
    }

    var itemCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }
}
