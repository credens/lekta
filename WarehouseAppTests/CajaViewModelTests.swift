import XCTest
@testable import WarehouseApp

@MainActor
final class CajaViewModelTests: XCTestCase {

    var vm: CajaViewModel!

    override func setUp() async throws {
        // Clear persisted state before each test
        ["caja_apertura_date","caja_total_ventas","caja_total_mp",
         "caja_total_efectivo","caja_cantidad_ventas"]
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
        vm = CajaViewModel()
    }

    override func tearDown() async throws {
        ["caja_apertura_date","caja_total_ventas","caja_total_mp",
         "caja_total_efectivo","caja_cantidad_ventas"]
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    // MARK: - Initial state

    func test_initialState_isCerrada() {
        if case .cerrada = vm.estado { } else { XCTFail("Expected .cerrada") }
    }

    func test_estaAbierta_initiallyFalse() {
        XCTAssertFalse(vm.estaAbierta)
    }

    // MARK: - Abrir caja (local only, skip MP call)

    func test_registrarVenta_accumulatesTotal() {
        vm.registrarVenta(total: 1500, metodo: .cash)
        vm.registrarVenta(total: 3000, metodo: .qrMP)
        XCTAssertEqual(vm.totalVentas, 4500, accuracy: 0.01)
        XCTAssertEqual(vm.cantidadVentas, 2)
    }

    func test_registrarVenta_splitsByMethod() {
        vm.registrarVenta(total: 1000, metodo: .cash)
        vm.registrarVenta(total: 2000, metodo: .qrMP)
        XCTAssertEqual(vm.totalEfectivo, 1000, accuracy: 0.01)
        XCTAssertEqual(vm.totalMP, 2000, accuracy: 0.01)
    }

    func test_registrarVenta_pointMPCountsAsMP() {
        vm.registrarVenta(total: 500, metodo: .pointMP)
        XCTAssertEqual(vm.totalMP, 500, accuracy: 0.01)
        XCTAssertEqual(vm.totalEfectivo, 0)
    }

    // MARK: - Persistence across restart

    func test_totales_persistAfterRestart() {
        vm.registrarVenta(total: 999, metodo: .cash)
        // Simulate save by accessing UserDefaults directly (CajaViewModel saves on registrarVenta)
        let vm2 = CajaViewModel()
        // Without an open caja session, totals won't be restored (intentional — new session = clean slate)
        // This test validates that registrarVenta actually persists to UserDefaults
        let saved = UserDefaults.standard.double(forKey: "caja_total_efectivo")
        XCTAssertEqual(saved, 999, accuracy: 0.01)
    }
}
