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
        case .tier1: return "Básico"
        case .tier2: return "Pro"
        case .tier3: return "Business"
        case .full:  return "Enterprise"
        }
    }

    var maxProducts: Int {
        switch self {
        case .free:  return 25
        case .tier1: return 250
        case .tier2: return 500
        case .tier3: return 1_000
        case .full:  return 2_500
        }
    }

    var maxDevices: Int {
        switch self {
        case .free:  return 1
        case .tier1: return 1
        case .tier2: return 5
        case .tier3: return 15
        case .full:  return 50
        }
    }

    var includesCloudBackup: Bool { self != .free }
    var includesReports: Bool     { self != .free }
    var lowStockAlerts: Bool      { self >= .tier2 }
    var dataExport: Bool          { self >= .tier3 }
    var prioritySupport: Bool     { self == .full }

    var badge: String {
        switch self {
        case .free:  return "🆓"
        case .tier1: return "⭐"
        case .tier2: return "🚀"
        case .tier3: return "💼"
        case .full:  return "🏆"
        }
    }

    var features: [String] {
        var f = ["Hasta \(maxProducts) productos", "\(maxDevices == 1 ? "1 dispositivo" : "Hasta \(maxDevices) dispositivos")"]
        if includesCloudBackup { f.append("Backup diario en la nube") }
        if includesReports     { f.append("Reportes de ventas") }
        if lowStockAlerts      { f.append("Alertas de stock bajo") }
        if dataExport          { f.append("Exportar datos (CSV)") }
        if prioritySupport     { f.append("Soporte prioritario") }
        return f
    }
}

extension SubscriptionTier: Comparable {
    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        let order: [SubscriptionTier] = [.free, .tier1, .tier2, .tier3, .full]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}
