package com.lekta.app.services

import com.lekta.app.Config
import com.lekta.app.models.CartItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.floor

data class PreferenceResponse(
    val id: String,
    val initPoint: String,
    val sandboxInitPoint: String
)

enum class PaymentStatus { PENDING, APPROVED, REJECTED, CANCELLED }

@Singleton
class MercadoPagoService @Inject constructor(
    private val securePrefs: SecurePrefs
) {
    private val accessToken: String get() = securePrefs.mpAccessToken ?: ""

    companion object {
        private const val CONNECT_TIMEOUT_MS = 15_000
        private const val READ_TIMEOUT_MS = 30_000
    }

    private fun HttpURLConnection.applyDefaults() {
        connectTimeout = CONNECT_TIMEOUT_MS
        readTimeout = READ_TIMEOUT_MS
        useCaches = false
    }

    suspend fun createPreference(items: List<CartItem>): PreferenceResponse = withContext(Dispatchers.IO) {
        val conn = (URL("${Config.MP_BASE_URL}/checkout/preferences").openConnection() as HttpURLConnection).apply {
            applyDefaults()
            requestMethod = "POST"
            setRequestProperty("Authorization", "Bearer $accessToken")
            setRequestProperty("Content-Type", "application/json")
            doOutput = true
        }

        try {
            val mpItems = JSONArray()
            items.forEach { item ->
                mpItems.put(JSONObject().apply {
                    put("title", item.product.name)
                    put("quantity", item.quantity)
                    put("unit_price", item.product.finalPrice)
                    put("currency_id", "ARS")
                })
            }

            val total = items.sumOf { it.product.finalPrice * it.quantity }
            val marketplaceFee = floor(total * Config.MARKETPLACE_FEE_PERCENT / 100.0 * 100) / 100

            val body = JSONObject().apply {
                put("items", mpItems)
                put("marketplace_fee", marketplaceFee)
                put("marketplace", Config.MP_CLIENT_ID)
            }

            conn.outputStream.use { it.write(body.toString().toByteArray()) }

            if (conn.responseCode != 201) throw Exception("HTTP ${conn.responseCode}")

            val response = JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
            PreferenceResponse(
                id = response.getString("id"),
                initPoint = response.getString("init_point"),
                sandboxInitPoint = response.getString("sandbox_init_point")
            )
        } finally {
            conn.disconnect()
        }
    }

    suspend fun checkPaymentStatus(preferenceId: String): PaymentStatus = withContext(Dispatchers.IO) {
        if (!preferenceId.all { it.isLetterOrDigit() || it == '-' || it == '_' }) {
            throw IllegalArgumentException("Invalid preference ID")
        }

        val conn = (URL("${Config.MP_BASE_URL}/checkout/preferences/$preferenceId").openConnection() as HttpURLConnection).apply {
            applyDefaults()
            setRequestProperty("Authorization", "Bearer $accessToken")
        }

        try {
            if (conn.responseCode !in 200..299) throw Exception("HTTP ${conn.responseCode}")

            val json = JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
            val status = json.optString("status", "pending")
            PaymentStatus.entries.find { it.name.equals(status, ignoreCase = true) } ?: PaymentStatus.PENDING
        } finally {
            conn.disconnect()
        }
    }

    suspend fun verificarPOS(): Unit = withContext(Dispatchers.IO) {
        val conn = (URL("${Config.MP_BASE_URL}/pos").openConnection() as HttpURLConnection).apply {
            applyDefaults()
            setRequestProperty("Authorization", "Bearer $accessToken")
        }
        try {
            if (conn.responseCode !in 200..299) throw Exception("HTTP ${conn.responseCode}")
        } finally {
            conn.disconnect()
        }
    }

    suspend fun obtenerTotalPagos(desde: Date): Double = withContext(Dispatchers.IO) {
        val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

        val conn = (URL(
            "${Config.MP_BASE_URL}/v1/payments/search" +
                    "?status=approved" +
                    "&begin_date=${fmt.format(desde)}" +
                    "&end_date=${fmt.format(Date())}" +
                    "&limit=100"
        ).openConnection() as HttpURLConnection).apply {
            applyDefaults()
            setRequestProperty("Authorization", "Bearer $accessToken")
        }

        try {
            if (conn.responseCode !in 200..299) throw Exception("HTTP ${conn.responseCode}")

            val json = JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
            val results = json.getJSONArray("results")
            var total = 0.0
            for (i in 0 until results.length()) {
                total += results.getJSONObject(i).getDouble("transaction_amount")
            }
            total
        } finally {
            conn.disconnect()
        }
    }
}
