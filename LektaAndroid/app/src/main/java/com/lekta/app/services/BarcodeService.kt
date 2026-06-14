package com.lekta.app.services

import com.lekta.app.models.Product
import com.lekta.app.models.ScanResult
import java.net.URI

object BarcodeService {

    fun isEAN13(s: String): Boolean {
        if (s.length != 13 || !s.all { it.isDigit() }) return false
        val digits = s.map { it.digitToInt() }
        val sum = digits.dropLast(1).mapIndexed { i, d ->
            d * if (i % 2 == 0) 1 else 3
        }.sum()
        val check = (10 - (sum % 10)) % 10
        return check == digits[12]
    }

    fun isMercadoPagoQR(s: String): Boolean {
        val host = try {
            URI(s).host?.lowercase()
        } catch (_: Exception) {
            null
        } ?: return false
        val mpHosts = listOf(
            "mercadopago.com", "mercadopago.com.ar", "mercadopago.com.mx",
            "mercadopago.com.co", "mercadopago.com.br", "mpago.la"
        )
        return mpHosts.any { host == it || host.endsWith(".$it") }
    }

    fun classify(raw: String, products: List<Product>): ScanResult {
        val product = products.find { it.barcode == raw }
        if (product != null) return ScanResult.ProductFound(product)
        if (isMercadoPagoQR(raw)) return ScanResult.MercadoPagoQR(raw)
        return ScanResult.Unknown(raw)
    }

    fun sanitizedPrice(input: String): Double {
        val cleaned = input.filter { it.isDigit() || it == '.' || it == ',' }
            .replace(',', '.')
        return (cleaned.toDoubleOrNull() ?: 0.0).coerceIn(0.0, 9_999_999.0)
    }

    fun sanitizedStock(input: String): Int {
        return (input.filter { it.isDigit() }.toIntOrNull() ?: 0).coerceIn(0, 99_999)
    }
}
