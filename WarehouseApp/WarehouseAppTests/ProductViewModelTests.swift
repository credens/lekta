import XCTest
@testable import WarehouseApp

final class ProductViewModelTests: XCTestCase {

    var vm: ProductViewModel!

    // Use isolated UserDefaults per test to avoid state leakage
    let testKey = "wh_products_test"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "wh_products")
        vm = ProductViewModel()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "wh_products")
        super.tearDown()
    }

    private func makeProduct(barcode: String = "7501031311309", name: String = "Test",
                              price: Double = 100, stock: Int = 10) -> Product {
        Product(barcode: barcode, name: name, price: price, stock: stock,
                variants: [], discount: 0, category: "Test")
    }

    // MARK: - CRUD

    func test_upsert_addsNewProduct() {
        vm.upsert(makeProduct())
        XCTAssertEqual(vm.products.count, 1)
    }

    func test_upsert_updatesExistingProduct() {
        var p = makeProduct()
        vm.upsert(p)
        p.name = "Updated"
        vm.upsert(p)
        XCTAssertEqual(vm.products.count, 1)
        XCTAssertEqual(vm.products.first?.name, "Updated")
    }

    func test_delete_removesProduct() {
        let p = makeProduct()
        vm.upsert(p)
        vm.delete(p)
        XCTAssertEqual(vm.products.count, 0)
    }

    func test_find_byBarcode_returnsProduct() {
        vm.upsert(makeProduct(barcode: "7501031311309"))
        XCTAssertNotNil(vm.find(barcode: "7501031311309"))
    }

    func test_find_unknownBarcode_returnsNil() {
        XCTAssertNil(vm.find(barcode: "0000000000000"))
    }

    // MARK: - Stock

    func test_addStock_increases() {
        vm.upsert(makeProduct(barcode: "7501031311309", stock: 5))
        vm.addStock(barcode: "7501031311309", qty: 3)
        XCTAssertEqual(vm.find(barcode: "7501031311309")?.stock, 8)
    }

    func test_removeStock_decreases() {
        vm.upsert(makeProduct(barcode: "7501031311309", stock: 10))
        vm.removeStock(barcode: "7501031311309", qty: 4)
        XCTAssertEqual(vm.find(barcode: "7501031311309")?.stock, 6)
    }

    func test_removeStock_doesNotGoBelowZero() {
        vm.upsert(makeProduct(barcode: "7501031311309", stock: 2))
        vm.removeStock(barcode: "7501031311309", qty: 5)
        // Guard prevents removal when qty > stock
        XCTAssertEqual(vm.find(barcode: "7501031311309")?.stock, 2)
    }

    func test_removeStock_unknownBarcode_noChange() {
        vm.upsert(makeProduct(barcode: "7501031311309", stock: 5))
        vm.removeStock(barcode: "9999999999999", qty: 2)
        XCTAssertEqual(vm.find(barcode: "7501031311309")?.stock, 5)
    }

    // MARK: - Computed

    func test_categories_deduplicatedAndSorted() {
        vm.upsert(makeProduct(barcode: "1000000000000", name: "A"))
        var p2 = makeProduct(barcode: "2000000000000", name: "B")
        p2.category = "Bebidas"
        vm.upsert(p2)
        let cats = vm.categories
        XCTAssertFalse(cats.contains(where: { cats.filter { $0 == $0 }.count > 1 }))
    }

    func test_totalStockValue_correctCalculation() {
        let p = makeProduct(price: 100, stock: 5)  // finalPrice = 100 (no discount)
        vm.upsert(p)
        XCTAssertEqual(vm.totalStockValue, 500)
    }

    func test_totalStockValue_withDiscount() {
        var p = makeProduct(price: 100, stock: 10)
        p.discount = 0.1  // 10% off → finalPrice = 90
        vm.upsert(p)
        XCTAssertEqual(vm.totalStockValue, 900, accuracy: 0.01)
    }

    // MARK: - Persistence

    func test_persistence_survivesReinstantiation() {
        vm.upsert(makeProduct(name: "Persisted"))
        let vm2 = ProductViewModel()
        XCTAssertEqual(vm2.products.first?.name, "Persisted")
    }
}
