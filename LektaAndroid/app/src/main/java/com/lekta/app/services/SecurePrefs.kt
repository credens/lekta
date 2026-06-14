package com.lekta.app.services

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SecurePrefs @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val gson = Gson()

    private val masterKey: MasterKey by lazy {
        MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
    }

    private val prefs: SharedPreferences by lazy {
        EncryptedSharedPreferences.create(
            context,
            "lekta_secure_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    private val tokenPrefs: SharedPreferences by lazy {
        EncryptedSharedPreferences.create(
            context,
            "lekta_token_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    // -- Token storage (equivalent to iOS Keychain) --

    var mpAccessToken: String?
        get() = tokenPrefs.getString(KEY_ACCESS_TOKEN, null)
        set(value) = tokenPrefs.edit().putString(KEY_ACCESS_TOKEN, value).apply()

    var mpRefreshToken: String?
        get() = tokenPrefs.getString(KEY_REFRESH_TOKEN, null)
        set(value) = tokenPrefs.edit().putString(KEY_REFRESH_TOKEN, value).apply()

    var mpUserId: String?
        get() = tokenPrefs.getString(KEY_USER_ID, null)
        set(value) = tokenPrefs.edit().putString(KEY_USER_ID, value).apply()

    var mpExpiresAt: Long
        get() = tokenPrefs.getLong(KEY_EXPIRES_AT, 0L)
        set(value) = tokenPrefs.edit().putLong(KEY_EXPIRES_AT, value).apply()

    var skipMPAuth: Boolean
        get() = tokenPrefs.getBoolean(KEY_SKIP_AUTH, false)
        set(value) = tokenPrefs.edit().putBoolean(KEY_SKIP_AUTH, value).apply()

    val hasMPToken: Boolean get() = mpAccessToken != null

    fun deleteAllTokens() {
        tokenPrefs.edit().clear().apply()
    }

    // -- Encrypted data storage (equivalent to iOS SecureStorage + UserDefaults) --

    fun <T> saveEncrypted(key: String, value: T) {
        val json = gson.toJson(value)
        prefs.edit().putString(key, json).apply()
    }

    inline fun <reified T> loadEncrypted(key: String): T? {
        val json = prefs.getString(key, null) ?: return null
        return try {
            gson.fromJson(json, object : TypeToken<T>() {}.type)
        } catch (_: Exception) {
            null
        }
    }

    fun removeEncrypted(key: String) {
        prefs.edit().remove(key).apply()
    }

    // -- Master PIN (separate namespace, not wiped by deleteAllTokens) --

    private val masterPinPrefs: SharedPreferences by lazy {
        EncryptedSharedPreferences.create(
            context,
            "lekta_master_pin",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    var masterPinHash: String?
        get() = masterPinPrefs.getString("master_pin_hash", null)
        set(value) = masterPinPrefs.edit().putString("master_pin_hash", value).apply()

    companion object {
        private const val KEY_ACCESS_TOKEN = "mp_access_token"
        private const val KEY_REFRESH_TOKEN = "mp_refresh_token"
        private const val KEY_USER_ID = "mp_user_id"
        private const val KEY_EXPIRES_AT = "mp_expires_at"
        private const val KEY_SKIP_AUTH = "skip_mp_auth"
    }
}
