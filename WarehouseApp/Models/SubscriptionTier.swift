import Foundation

enum SubscriptionTier: String, Codable, CaseIterable {
    case free     = "free"
    case tier1    = "tier1"
    case tier2    = "tier2"
    case tier3    = "tier3"
    case full     = "full"

    var displayName: String {
        switch self {
        case .free:  return "Gratuito"
        case .tier1: return "Reportes mensuales"
        case .tier2: return "Reportes mensuales"
        case .tier3: return "Reportes mensuales"
        case .full:  return "Reportes mensuales"
        }
    }

    var maxProducts: Int {
        switch self {
        case .free:  return 250
        case .tier1: return 250
        case .tier2: return 250
        case .tier3: return 250
        case .full:  return 250
        }
    }

    var maxDevices: Int {
        1
    }

    var includesCloudBackup: Bool { false }
    var includesReports: Bool     { self != .free }
    var lowStockAlerts: Bool      { false }
    var dataExport: Bool          { includesReports }
    var prioritySupport: Bool     { false }

    var badge: String {
        switch self {
        case .free:  return "🆓"
        case .tier1: return "📊"
        case .tier2: return "📊"
        case .tier3: return "📊"
        case .full:  return "📊"
        }
    }

    var features: [String] {
        var f = ["Hasta \(maxProducts) productos", "Sin abono mensual"]
        if includesReports {
            f.append("Reportes mensuales de ventas")
            f.append("Exportar datos para administración")
        } else {
            f.append("Pagás comisión solo cuando cobrás")
        }
        return f
    }
}

extension SubscriptionTier: Comparable {
    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        let order: [SubscriptionTier] = [.free, .tier1, .tier2, .tier3, .full]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}
