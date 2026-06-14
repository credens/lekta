package com.lekta.app.models

import java.util.UUID

data class DailySummary(
    val id: String = UUID.randomUUID().toString(),
    val date: Long = System.currentTimeMillis(),
    val totalVentas: Double,
    val totalMP: Double,
    val totalEfectivo: Double,
    val cantidadVentas: Int,
    val operadorName: String? = null
) {
    val dominantMethod: String
        get() = if (totalMP >= totalEfectivo) "QR / MP" else "Efectivo"
}
