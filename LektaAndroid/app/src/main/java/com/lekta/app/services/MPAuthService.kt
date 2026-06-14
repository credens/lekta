package com.lekta.app.services

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import com.lekta.app.Config
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class MPAuthService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val securePrefs: SecurePrefs
) {
    private val _isAuthenticated = MutableStateFlow(
        securePrefs.hasMPToken || securePrefs.skipMPAuth
    )
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    private var codeVerifier: String? = null
    private var oauthState: String? = null

    fun skipAuthentication() {
        securePrefs.skipMPAuth = true
        _isAuthenticated.value = true
    }

    fun buildAuthIntent(): Intent {
        _errorMessage.value = null
        val verifier = makeCodeVerifier()
        val challenge = makeCodeChallenge(verifier)
        val state = UUID.randomUUID().toString()
        codeVerifier = verifier
        oauthState = state

        val uri = Uri.parse(Config.MP_AUTH_URL).buildUpon()
            .appendQueryParameter("client_id", Config.MP_CLIENT_ID)
            .appendQueryParameter("response_type", "code")
            .appendQueryParameter("redirect_uri", Config.MP_REDIRECT_URI)
            .appendQueryParameter("code_challenge", challenge)
            .appendQueryParameter("code_challenge_method", "S256")
            .appendQueryParameter("state", state)
            .build()

        return CustomTabsIntent.Builder().build().intent.apply {
            data = uri
        }
    }

    fun handleCallback(uri: Uri): Boolean {
        val returnedState = uri.getQueryParameter("state")
        if (returnedState != oauthState) {
            _errorMessage.value = "Error de seguridad en el proceso de autenticación."
            oauthState = null
            return false
        }
        oauthState = null

        val error = uri.getQueryParameter("error")
        if (error != null) {
            val desc = uri.getQueryParameter("error_description") ?: error
            _errorMessage.value = "MercadoPago: $desc"
            return false
        }

        val code = uri.getQueryParameter("code")
        if (code == null) {
            _errorMessage.value = "No se recibió el código de autorización."
            return false
        }

        return true
    }

    fun getCodeFromUri(uri: Uri): String? = uri.getQueryParameter("code")

    suspend fun exchangeCode(code: String) {
        _isLoading.value = true
        val verifier = codeVerifier
        codeVerifier = null

        if (verifier == null) {
            _errorMessage.value = "Error interno en el proceso de autenticación."
            _isLoading.value = false
            return
        }

        try {
            val response = withContext(Dispatchers.IO) {
                val conn = (URL(Config.MP_TOKEN_URL).openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                    connectTimeout = 15_000
                    readTimeout = 30_000
                    useCaches = false
                    doOutput = true
                }

                try {
                    val params = mapOf(
                        "client_id" to Config.MP_CLIENT_ID,
                        "client_secret" to Config.MP_CLIENT_SECRET,
                        "code" to code,
                        "redirect_uri" to Config.MP_REDIRECT_URI,
                        "grant_type" to "authorization_code",
                        "code_verifier" to verifier
                    )
                    val body = params.entries.joinToString("&") { (k, v) ->
                        "${URLEncoder.encode(k, "UTF-8")}=${URLEncoder.encode(v, "UTF-8")}"
                    }
                    conn.outputStream.use { it.write(body.toByteArray()) }

                    if (conn.responseCode !in 200..299) {
                        throw Exception("HTTP ${conn.responseCode}")
                    }
                    conn.inputStream.bufferedReader().use { it.readText() }
                } finally {
                    conn.disconnect()
                }
            }

            val json = JSONObject(response)
            securePrefs.mpAccessToken = json.getString("access_token")
            securePrefs.mpRefreshToken = json.getString("refresh_token")
            securePrefs.mpUserId = json.getInt("user_id").toString()
            securePrefs.mpExpiresAt = System.currentTimeMillis() + json.getLong("expires_in") * 1000
            _isAuthenticated.value = true
        } catch (_: Exception) {
            _errorMessage.value = "No se pudo completar la autenticación."
        } finally {
            _isLoading.value = false
        }
    }

    fun desconectar() {
        securePrefs.deleteAllTokens()
        _isAuthenticated.value = false
    }

    private fun makeCodeVerifier(): String {
        val bytes = ByteArray(64)
        SecureRandom().nextBytes(bytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }

    private fun makeCodeChallenge(verifier: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.UTF_8))
        return Base64.getUrlEncoder().withoutPadding().encodeToString(digest)
    }
}
