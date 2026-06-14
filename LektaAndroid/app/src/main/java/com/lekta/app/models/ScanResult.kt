package com.lekta.app.models

sealed class ScanResult {
    data class ProductFound(val product: Product) : ScanResult()
    data class MercadoPagoQR(val url: String) : ScanResult()
    data class Unknown(val raw: String) : ScanResult()
}
