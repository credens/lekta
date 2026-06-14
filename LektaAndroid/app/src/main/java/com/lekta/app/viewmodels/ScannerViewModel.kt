package com.lekta.app.viewmodels

import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject

@HiltViewModel
class ScannerViewModel @Inject constructor() : ViewModel() {

    private val _scannedCode = MutableStateFlow<String?>(null)
    val scannedCode: StateFlow<String?> = _scannedCode

    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning

    fun onBarcodeDetected(value: String) {
        if (value.isEmpty() || value == _scannedCode.value) return
        _scannedCode.value = value
        _isRunning.value = false
    }

    fun resumeScanning() {
        _scannedCode.value = null
        _isRunning.value = true
    }

    fun startSession() {
        _isRunning.value = true
    }

    fun stopSession() {
        _isRunning.value = false
    }
}
