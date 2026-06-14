package com.lekta.app.models

import java.security.MessageDigest
import java.util.UUID

data class Operador(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val pinHash: String,
    var isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis()
) {
    fun verifyPIN(pin: String): Boolean = pinHash == hashPIN(pin)

    companion object {
        fun hashPIN(pin: String): String {
            val digest = MessageDigest.getInstance("SHA-256")
            return digest.digest(pin.toByteArray(Charsets.UTF_8))
                .joinToString("") { "%02x".format(it) }
        }
    }
}
