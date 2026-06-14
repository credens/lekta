import Foundation

struct DailySummary: Identifiable, Codable {
    var id: UUID = UUID()
    let date: Date
    let totalVentas: Double
    let totalMP: Double
    let totalEfectivo: Double
    let cantidadVentas: Int
    var operadorName: String?

    var dominantMethod: String {
        totalMP >= totalEfectivo ? "QR / MP" : "Efectivo"
    }
}
