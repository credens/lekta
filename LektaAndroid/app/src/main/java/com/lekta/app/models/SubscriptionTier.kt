package com.lekta.app.models

enum class SubscriptionTier(
    val displayName: String,
    val maxProducts: Int,
    val maxDevices: Int,
    val badge: String
) {
    FREE("Gratuito", 250, 1, "🆓"),
    TIER1("Reportes mensuales", 250, 1, "📊"),
    TIER2("Reportes mensuales", 250, 1, "📊"),
    TIER3("Reportes mensuales", 250, 1, "📊"),
    FULL("Reportes mensuales", 250, 1, "📊");

    val includesCloudBackup: Boolean get() = false
    val includesReports: Boolean get() = this != FREE
    val lowStockAlerts: Boolean get() = false
    val dataExport: Boolean get() = includesReports
    val prioritySupport: Boolean get() = false

    val features: List<String>
        get() = buildList {
            add("Hasta $maxProducts productos")
            add("Sin abono mensual")
            if (includesReports) {
                add("Reportes mensuales de ventas")
                add("Exportar datos para administración")
            } else {
                add("Pagás comisión solo cuando cobrás")
            }
        }
}
