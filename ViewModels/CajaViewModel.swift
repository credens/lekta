import Foundation
import Combine

enum CajaEstado {
    case cerrada
    case abriendo
    case abierta(desde: Date)
    case cerrando
}

struct ResumenCaja {
    let apertura: Date
    let cierre: Date
    let totalVentas: Double
    let totalMP: Double
    let totalEfectivo: Double
    let cantidadVentas: Int
}

@MainActor
class CajaViewModel: ObservableObject {
    @Published var estado: CajaEstado = .cerrada
    @Published var totalVentas: Double = 0
    @Published var totalMP: Double = 0
    @Published var totalEfectivo: Double = 0
    @Published var cantidadVentas: Int = 0
    @Published var errorMessage: String?
    @Published var ultimoResumen: ResumenCaja?

    private let defaults = UserDefaults.standard
    private let keyAperturaDate = "caja_apertura_date"
    private let keyTotalVentas  = "caja_total_ventas"
    private let keyTotalMP      = "caja_total_mp"
    private let keyTotalEfectivo = "caja_total_efectivo"
    private let keyCantidad     = "caja_cantidad_ventas"

    init() { restoreEstado() }

    var estaAbierta: Bool {
        if case .abierta = estado { return true }
        return false
    }

    var horaApertura: Date? {
        if case .abierta(let d) = estado { return d }
        return nil
    }

    // MARK: - Abrir caja

    func abrirCaja() async {
        guard case .cerrada = estado else { return }
        estado = .abriendo
        errorMessage = nil

        // 1. Verificar POS en MP
        do {
            try await MercadoPagoService.verificarPOS()
        } catch {
            // No bloqueante: loguear pero permitir abrir igual (puede estar offline)
            print("MP POS check: \(error.localizedDescription)")
        }

        // 2. Abrir caja local
        let ahora = Date()
        totalVentas = 0; totalMP = 0; totalEfectivo = 0; cantidadVentas = 0
        persistirSesion(apertura: ahora)
        estado = .abierta(desde: ahora)
    }

    // MARK: - Registrar venta (llamado desde CheckoutViewModel al confirmar cobro)

    func registrarVenta(total: Double, metodo: PaymentMethod) {
        totalVentas += total
        cantidadVentas += 1
        switch metodo {
        case .qrMP, .pointMP: totalMP += total
        case .cash:            totalEfectivo += total
        }
        defaults.set(totalVentas, forKey: keyTotalVentas)
        defaults.set(totalMP, forKey: keyTotalMP)
        defaults.set(totalEfectivo, forKey: keyTotalEfectivo)
        defaults.set(cantidadVentas, forKey: keyCantidad)
    }

    // MARK: - Cerrar caja

    func cerrarCaja() async {
        guard case .abierta(let apertura) = estado else { return }
        estado = .cerrando
        errorMessage = nil

        // 1. Obtener pagos del día desde MP para conciliar
        var totalMPConfirmado = totalMP
        do {
            totalMPConfirmado = try await MercadoPagoService.obtenerTotalPagos(desde: apertura)
        } catch {
            print("MP pagos: \(error.localizedDescription)")
        }

        // 2. Guardar resumen
        ultimoResumen = ResumenCaja(
            apertura: apertura,
            cierre: Date(),
            totalVentas: totalVentas,
            totalMP: totalMPConfirmado,
            totalEfectivo: totalEfectivo,
            cantidadVentas: cantidadVentas
        )

        // 3. Limpiar sesión
        limpiarSesion()
        estado = .cerrada
    }

    // MARK: - Persistencia

    private func persistirSesion(apertura: Date) {
        defaults.set(apertura, forKey: keyAperturaDate)
        defaults.set(0.0, forKey: keyTotalVentas)
        defaults.set(0.0, forKey: keyTotalMP)
        defaults.set(0.0, forKey: keyTotalEfectivo)
        defaults.set(0, forKey: keyCantidad)
    }

    private func limpiarSesion() {
        [keyAperturaDate, keyTotalVentas, keyTotalMP, keyTotalEfectivo, keyCantidad]
            .forEach { defaults.removeObject(forKey: $0) }
    }

    private func restoreEstado() {
        guard let apertura = defaults.object(forKey: keyAperturaDate) as? Date else { return }
        totalVentas    = defaults.double(forKey: keyTotalVentas)
        totalMP        = defaults.double(forKey: keyTotalMP)
        totalEfectivo  = defaults.double(forKey: keyTotalEfectivo)
        cantidadVentas = defaults.integer(forKey: keyCantidad)
        estado = .abierta(desde: apertura)
    }
}
