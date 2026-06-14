package com.lekta.app.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lekta.app.models.Operador
import com.lekta.app.models.PaymentMethod
import com.lekta.app.services.MercadoPagoService
import com.lekta.app.services.SecurePrefs
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.util.Date
import javax.inject.Inject

sealed class CajaEstado {
    data object Cerrada : CajaEstado()
    data object Abriendo : CajaEstado()
    data class Abierta(val desde: Long) : CajaEstado()
    data object Cerrando : CajaEstado()
}

data class ResumenCaja(
    val apertura: Long,
    val cierre: Long,
    val totalVentas: Double,
    val totalMP: Double,
    val totalEfectivo: Double,
    val cantidadVentas: Int,
    val operadorName: String?
)

@HiltViewModel
class CajaViewModel @Inject constructor(
    private val securePrefs: SecurePrefs,
    private val mpService: MercadoPagoService
) : ViewModel() {

    private val _estado = MutableStateFlow<CajaEstado>(CajaEstado.Cerrada)
    val estado: StateFlow<CajaEstado> = _estado

    private val _totalVentas = MutableStateFlow(0.0)
    val totalVentas: StateFlow<Double> = _totalVentas

    private val _totalMP = MutableStateFlow(0.0)
    val totalMP: StateFlow<Double> = _totalMP

    private val _totalEfectivo = MutableStateFlow(0.0)
    val totalEfectivo: StateFlow<Double> = _totalEfectivo

    private val _cantidadVentas = MutableStateFlow(0)
    val cantidadVentas: StateFlow<Int> = _cantidadVentas

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    private val _ultimoResumen = MutableStateFlow<ResumenCaja?>(null)
    val ultimoResumen: StateFlow<ResumenCaja?> = _ultimoResumen

    private val _currentOperadorName = MutableStateFlow<String?>(null)
    val currentOperadorName: StateFlow<String?> = _currentOperadorName

    private val sessionKey = "caja_session_v2"

    val estaAbierta: Boolean get() = _estado.value is CajaEstado.Abierta

    val horaApertura: Long?
        get() = (_estado.value as? CajaEstado.Abierta)?.desde

    init { restoreEstado() }

    fun abrirCaja(operador: Operador) {
        if (_estado.value !is CajaEstado.Cerrada) return
        _estado.value = CajaEstado.Abriendo
        _errorMessage.value = null

        viewModelScope.launch {
            try { mpService.verificarPOS() } catch (_: Exception) {}

            val ahora = System.currentTimeMillis()
            _totalVentas.value = 0.0
            _totalMP.value = 0.0
            _totalEfectivo.value = 0.0
            _cantidadVentas.value = 0
            _currentOperadorName.value = operador.name
            persistirSesion(ahora)
            _estado.value = CajaEstado.Abierta(ahora)
        }
    }

    fun registrarVenta(total: Double, metodo: PaymentMethod) {
        if (total <= 0) return
        _totalVentas.value += total
        _cantidadVentas.value += 1
        when (metodo) {
            PaymentMethod.QR_MP, PaymentMethod.POINT_MP -> _totalMP.value += total
            PaymentMethod.CASH -> _totalEfectivo.value += total
        }
        val apertura = ((_estado.value as? CajaEstado.Abierta)?.desde) ?: return
        persistirSesion(apertura)
    }

    fun cerrarCaja() {
        val apertura = (_estado.value as? CajaEstado.Abierta)?.desde ?: return
        _estado.value = CajaEstado.Cerrando
        _errorMessage.value = null

        viewModelScope.launch {
            var totalMPConfirmado = _totalMP.value
            try {
                totalMPConfirmado = mpService.obtenerTotalPagos(Date(apertura))
            } catch (_: Exception) {}

            _ultimoResumen.value = ResumenCaja(
                apertura = apertura,
                cierre = System.currentTimeMillis(),
                totalVentas = _totalVentas.value,
                totalMP = totalMPConfirmado,
                totalEfectivo = _totalEfectivo.value,
                cantidadVentas = _cantidadVentas.value,
                operadorName = _currentOperadorName.value
            )

            _currentOperadorName.value = null
            securePrefs.removeEncrypted(sessionKey)
            _estado.value = CajaEstado.Cerrada
        }
    }

    private data class CajaSession(
        val apertura: Long,
        val operadorName: String?,
        val totalVentas: Double,
        val totalMP: Double,
        val totalEfectivo: Double,
        val cantidadVentas: Int
    )

    private fun persistirSesion(apertura: Long) {
        securePrefs.saveEncrypted(sessionKey, CajaSession(
            apertura = apertura,
            operadorName = _currentOperadorName.value,
            totalVentas = _totalVentas.value,
            totalMP = _totalMP.value,
            totalEfectivo = _totalEfectivo.value,
            cantidadVentas = _cantidadVentas.value
        ))
    }

    private fun restoreEstado() {
        val session = securePrefs.loadEncrypted<CajaSession>(sessionKey) ?: return
        _totalVentas.value = session.totalVentas
        _totalMP.value = session.totalMP
        _totalEfectivo.value = session.totalEfectivo
        _cantidadVentas.value = session.cantidadVentas
        _currentOperadorName.value = session.operadorName
        _estado.value = CajaEstado.Abierta(session.apertura)
    }
}
