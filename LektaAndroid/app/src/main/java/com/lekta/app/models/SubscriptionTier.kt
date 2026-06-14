package com.lekta.app.models

enum class SubscriptionTier(
    val displayName: String,
    val maxProducts: Int,
    val maxDevices: Int,
    val badge: String
) {
    FREE("Gratuito", 25, 1, "🆓"),
    TIER1("Básico", 250, 1, "⭐"),
    TIER2("Pro", 500, 5, "🚀"),
    TIER3("Business", 1_000, 15, "💼"),
    FULL("Enterprise", 2_500, 50, "🏆");

    val includesCloudBackup: Boolean get() = this != FREE
    val includesReports: Boolean get() = this != FREE
    val lowStockAlerts: Boolean get() = this >= TIER2
    val dataExport: Boolean get() = this >= TIER3
    val prioritySupport: Boolean get() = this == FULL

    val features: List<String>
        get() = buildList {
            add("Hasta $maxProducts productos")
            add(if (maxDevices == 1) "1 dispositivo" else "Hasta $maxDevices dispositivos")
            if (includesCloudBackup) add("Backup diario en la nube")
            if (includesReports) add("Reportes de ventas")
            if (lowStockAlerts) add("Alertas de stock bajo")
            if (dataExport) add("Exportar datos (CSV)")
            if (prioritySupport) add("Soporte prioritario")
        }
}
