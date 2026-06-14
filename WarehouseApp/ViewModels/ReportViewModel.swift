import Foundation
import Combine

@MainActor
class ReportViewModel: ObservableObject {
    @Published private(set) var summaries: [DailySummary] = []

    private let key = "report_history_v1"
    static let lowStockThreshold = 5

    init() { load() }

    func add(from resumen: ResumenCaja) {
        let summary = DailySummary(
            date: resumen.cierre,
            totalVentas: resumen.totalVentas,
            totalMP: resumen.totalMP,
            totalEfectivo: resumen.totalEfectivo,
            cantidadVentas: resumen.cantidadVentas,
            operadorName: resumen.operadorName
        )
        summaries.insert(summary, at: 0)
        save()
    }

    // MARK: - Aggregates

    var todayTotal:  Double { filtered(by: .day).reduce(0) { $0 + $1.totalVentas } }
    var todayCount:  Int    { filtered(by: .day).reduce(0) { $0 + $1.cantidadVentas } }
    var weekTotal:   Double { filtered(by: .weekOfYear).reduce(0) { $0 + $1.totalVentas } }
    var monthTotal:  Double { filtered(by: .month).reduce(0) { $0 + $1.totalVentas } }

    private func filtered(by component: Calendar.Component) -> [DailySummary] {
        summaries.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: component) }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded: [DailySummary] = SecureStorage.decryptCodable(data) else { return }
        summaries = decoded
    }

    private func save() {
        guard let data: Data = SecureStorage.encryptCodable(summaries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
