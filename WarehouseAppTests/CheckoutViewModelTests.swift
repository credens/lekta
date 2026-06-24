import XCTest
@testable import WarehouseApp

final class CheckoutViewModelTests: XCTestCase {

    var vm: CheckoutViewModel!

    override func setUp() {
        super.setUp()
        vm = CheckoutViewModel()
    }

    private func makeProduct(name: String = "P", price: Double = 100,
                              discount: Double = 0) -> Product {
        Product(barcode: "7501031311309", name: name, price: price,
                stock: 99, variants: [], discount: discount, category: "Test")
    }

    // MARK: - Add

    func test_add_newProduct_appendsItem() {
        vm.add(product: makeProduct())
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.quantity, 1)
    }

    func test_add_sameProduct_incrementsQuantity() {
        let p = makeProduct()
        vm.add(product: p)
        vm.add(product: p)
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertEqual(vm.items.first?.quantity, 2)
    }

    func test_add_differentProducts_appendsBoth() {
        var p2 = makeProduct(name: "B")
        p2 = Product(barcode: "9999999999999", name: "B", price: 200,
                     stock: 5, variants: [], discount: 0, category: "X")
        vm.add(product: makeProduct())
        vm.add(product: p2)
        XCTAssertEqual(vm.items.count, 2)
    }

    // MARK: - Remove / UpdateQty

    func test_remove_deletesItem() {
        vm.add(product: makeProduct())
        let item = vm.items.first!
        vm.remove(item: item)
        XCTAssertTrue(vm.items.isEmpty)
    }

    func test_updateQty_toZero_removesItem() {
        vm.add(product: makeProduct())
        let item = vm.items.first!
        vm.updateQty(item: item, qty: 0)
        XCTAssertTrue(vm.items.isEmpty)
    }

    func test_updateQty_negative_removesItem() {
        vm.add(product: makeProduct())
        let item = vm.items.first!
        vm.updateQty(item: item, qty: -1)
        XCTAssertTrue(vm.items.isEmpty)
    }

    func test_updateQty_positive_updatesQuantity() {
        vm.add(product: makeProduct())
        let item = vm.items.first!
        vm.updateQty(item: item, qty: 5)
        XCTAssertEqual(vm.items.first?.quantity, 5)
    }

    // MARK: - Clear

    func test_clear_emptiesCart() {
        vm.add(product: makeProduct())
        vm.add(product: makeProduct())
        vm.clear()
        XCTAssertTrue(vm.items.isEmpty)
    }

    // MARK: - Totals

    func test_total_noDiscount() {
        let p = makeProduct(price: 100, discount: 0)
        vm.add(product: p)
        vm.add(product: p)  // qty = 2
        XCTAssertEqual(vm.total, 200)
    }

    func test_total_withDiscount() {
        let p = makeProduct(price: 100, discount: 0.2)  // 20% off → $80
        vm.add(product: p)
        XCTAssertEqual(vm.total, 80, accuracy: 0.01)
    }

    func test_subtotalBeforeDiscount_ignoresDiscount() {
        let p = makeProduct(price: 100, discount: 0.5)
        vm.add(product: p)
        XCTAssertEqual(vm.subtotalBeforeDiscount, 100)
    }

    func test_discount_computedCorrectly() {
        let p = makeProduct(price: 100, discount: 0.1)  // $10 discount
        vm.add(product: p)
        XCTAssertEqual(vm.discount, 10, accuracy: 0.01)
    }

    func test_itemCount_sumsQuantities() {
        let p = makeProduct()
        vm.add(product: p); vm.add(product: p); vm.add(product: p)  // qty = 3
        XCTAssertEqual(vm.itemCount, 3)
    }

    func test_emptyCart_totalIsZero() {
        XCTAssertEqual(vm.total, 0)
        XCTAssertEqual(vm.itemCount, 0)
    }
}
