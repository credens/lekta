package com.lekta.app.models

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Money
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.Waves
import androidx.compose.ui.graphics.vector.ImageVector

enum class PaymentMethod(val label: String, val icon: ImageVector) {
    QR_MP("QR MP", Icons.Default.QrCode),
    POINT_MP("Point MP", Icons.Default.Waves),
    CASH("Efectivo", Icons.Default.Money);
}
