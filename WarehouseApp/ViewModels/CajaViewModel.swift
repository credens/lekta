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
    let operadorName: String?
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
    @Published private(set) var currentOperadorName: String?

    private let sessionKey = "caja_session_v2"

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

    func abrirCaja(operador: Operador) async {
        guard case .cerrada = estado else { return }
        estado = .abriendo
        errorMessage = nil

        do {
            try await MercadoPagoService.verificarPOS()
        } catch {
            // Non-blocking: allow opening while offline
        }

        let ahora = Date()
        totalVentas = 0; totalMP = 0; totalEfectivo = 0; cantidadVentas = 0
        currentOperadorName = operador.name
        persistirSesion(apertura: ahora)
        estado = .abierta(desde: ahora)
    }

    // MARK: - Registrar venta

    func registrarVenta(total: Double, metodo: PaymentMethod) {
        guard total > 0 else { return }
        totalVentas += total
        cantidadVentas += 1
        switch metodo {
        case .qrMP, .pointMP: totalMP += total
        case .cash:            totalEfectivo += total
        }
        guard case .abierta(let apertura) = estado else { return }
        persistirSesion(apertura: apertura)
    }

    // MARK: - Cerrar caja

    func cerrarCaja() async {
        guard case .abierta(let apertura) = estado else { return }
        estado = .cerrando
        errorMessage = nil

        var totalMPConfirmado = totalMP
        do {
            totalMPConfirmado = try await MercadoPagoService.obtenerTotalPagos(desde: apertura)
        } catch {
            // Fallback to local total if API call fails
        }

        ultimoResumen = ResumenCaja(
            apertura: apertura,
            cierre: Date(),
            totalVentas: totalVentas,
            totalMP: totalMPConfirmado,
            totalEfectivo: totalEfectivo,
            cantidadVentas: cantidadVentas,
            operadorName: currentOperadorName
        )

        currentOperadorName = nil
        limpiarSesion()
        estado = .cerrada
    }

    // MARK: - Encrypted persistence

    private struct CajaSession: Codable {
        let apertura: Date
        var operadorName: String?
        let totalVentas: Double
        let totalMP: Double
        let totalEfectivo: Double
        let cantidadVentas: Int
    }

    private func persistirSesion(apertura: Date) {
        let session = CajaSession(
            apertura: apertura,
            operadorName: currentOperadorName,
            totalVentas: totalVentas,
            totalMP: totalMP,
            totalEfectivo: totalEfectivo,
            cantidadVentas: cantidadVentas
        )
        guard let encrypted = SecureStorage.encryptCodable(session) else { return }
        UserDefaults.standard.set(encrypted, forKey: sessionKey)
    }

    private func limpiarSesion() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        migrateLegacyKeys()
    }

    private func restoreEstado() {
        if let encrypted = UserDefaults.standard.data(forKey: sessionKey),
           let session: CajaSession = SecureStorage.decryptCodable(encrypted) {
            totalVentas         = session.totalVentas
            totalMP             = session.totalMP
            totalEfectivo       = session.totalEfectivo
            cantidadVentas      = session.cantidadVentas
            currentOperadorName = session.operadorName
            estado = .abierta(desde: session.apertura)
            return
        }
        // One-time migration from legacy plaintext keys
        let ud = UserDefaults.standard
        let legacyKey = "caja_apertura_date"
        if let apertura = ud.object(forKey: legacyKey) as? Date {
            totalVentas    = ud.double(forKey: "caja_total_ventas")
            totalMP        = ud.double(forKey: "caja_total_mp")
            totalEfectivo  = ud.double(forKey: "caja_total_efectivo")
            cantidadVentas = ud.integer(forKey: "caja_cantidad_ventas")
            estado = .abierta(desde: apertura)
            persistirSesion(apertura: apertura)
            migrateLegacyKeys()
        }
    }

    private func migrateLegacyKeys() {
        ["caja_apertura_date", "caja_total_ventas", "caja_total_mp",
         "caja_total_efectivo", "caja_cantidad_ventas"].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
    }
}
