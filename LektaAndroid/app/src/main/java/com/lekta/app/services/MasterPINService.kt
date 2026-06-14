package com.lekta.app.services

import com.lekta.app.models.Operador
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class MasterPINService @Inject constructor(
    private val securePrefs: SecurePrefs
) {
    val isSet: Boolean get() = securePrefs.masterPinHash != null

    fun create(pin: String): Boolean {
        if (pin.length != 4 || !pin.all { it.isDigit() }) return false
        securePrefs.masterPinHash = Operador.hashPIN(pin)
        return true
    }

    fun verify(pin: String): Boolean {
        val stored = securePrefs.masterPinHash ?: return false
        return stored == Operador.hashPIN(pin)
    }
}
