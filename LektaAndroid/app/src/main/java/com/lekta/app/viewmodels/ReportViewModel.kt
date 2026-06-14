package com.lekta.app.viewmodels

import androidx.lifecycle.ViewModel
import com.lekta.app.models.DailySummary
import com.lekta.app.services.SecurePrefs
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.Calendar
import javax.inject.Inject

@HiltViewModel
class ReportViewModel @Inject constructor(
    private val securePrefs: SecurePrefs
) : ViewModel() {

    private val _summaries = MutableStateFlow<List<DailySummary>>(emptyList())
    val summaries: StateFlow<List<DailySummary>> = _summaries

    private val storageKey = "report_history_v1"

    init { load() }

    fun add(resumen: ResumenCaja) {
        val summary = DailySummary(
            date = resumen.cierre,
            totalVentas = resumen.totalVentas,
            totalMP = resumen.totalMP,
            totalEfectivo = resumen.totalEfectivo,
            cantidadVentas = resumen.cantidadVentas,
            operadorName = resumen.operadorName
        )
        _summaries.value = listOf(summary) + _summaries.value
        save()
    }

    val todayTotal: Double get() = filtered(Calendar.DAY_OF_YEAR).sumOf { it.totalVentas }
    val todayCount: Int get() = filtered(Calendar.DAY_OF_YEAR).sumOf { it.cantidadVentas }
    val weekTotal: Double get() = filtered(Calendar.WEEK_OF_YEAR).sumOf { it.totalVentas }
    val monthTotal: Double get() = filtered(Calendar.MONTH).sumOf { it.totalVentas }

    private fun filtered(field: Int): List<DailySummary> {
        val now = Calendar.getInstance()
        return _summaries.value.filter { summary ->
            val cal = Calendar.getInstance().apply { timeInMillis = summary.date }
            cal.get(field) == now.get(field) && cal.get(Calendar.YEAR) == now.get(Calendar.YEAR)
        }
    }

    private fun load() {
        _summaries.value = securePrefs.loadEncrypted<List<DailySummary>>(storageKey) ?: emptyList()
    }

    private fun save() {
        securePrefs.saveEncrypted(storageKey, _summaries.value)
    }

    companion object {
        const val LOW_STOCK_THRESHOLD = 5
    }
}
