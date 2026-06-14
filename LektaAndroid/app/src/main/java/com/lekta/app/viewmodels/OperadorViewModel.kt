package com.lekta.app.viewmodels

import androidx.lifecycle.ViewModel
import com.lekta.app.models.Operador
import com.lekta.app.services.SecurePrefs
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject

@HiltViewModel
class OperadorViewModel @Inject constructor(
    private val securePrefs: SecurePrefs
) : ViewModel() {

    private val _operadores = MutableStateFlow<List<Operador>>(emptyList())
    val operadores: StateFlow<List<Operador>> = _operadores

    private val storageKey = "operadores_v1"

    init { load() }

    val activeOperadores: List<Operador> get() = _operadores.value.filter { it.isActive }

    fun add(name: String, pin: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty() || pin.length != 4) return
        val op = Operador(name = trimmed, pinHash = Operador.hashPIN(pin))
        _operadores.value = _operadores.value + op
        save()
    }

    fun deactivate(operador: Operador) {
        _operadores.value = _operadores.value.map {
            if (it.id == operador.id) it.copy(isActive = false) else it
        }
        save()
    }

    fun reactivate(operador: Operador) {
        _operadores.value = _operadores.value.map {
            if (it.id == operador.id) it.copy(isActive = true) else it
        }
        save()
    }

    fun login(id: String, pin: String): Operador? {
        val op = _operadores.value.find { it.id == id && it.isActive } ?: return null
        return if (op.verifyPIN(pin)) op else null
    }

    private fun load() {
        _operadores.value = securePrefs.loadEncrypted<List<Operador>>(storageKey) ?: emptyList()
    }

    private fun save() {
        securePrefs.saveEncrypted(storageKey, _operadores.value)
    }
}
