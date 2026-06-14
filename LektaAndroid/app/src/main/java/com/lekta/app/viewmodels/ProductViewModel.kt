package com.lekta.app.viewmodels

import androidx.lifecycle.ViewModel
import com.lekta.app.models.Product
import com.lekta.app.services.SecurePrefs
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject

@HiltViewModel
class ProductViewModel @Inject constructor(
    private val securePrefs: SecurePrefs
) : ViewModel() {

    private val _products = MutableStateFlow<List<Product>>(emptyList())
    val products: StateFlow<List<Product>> = _products

    private val storageKey = "wh_products_v2"

    init { load() }

    private fun load() {
        _products.value = securePrefs.loadEncrypted<List<Product>>(storageKey) ?: emptyList()
    }

    private fun save() {
        securePrefs.saveEncrypted(storageKey, _products.value)
    }

    fun find(barcode: String): Product? = _products.value.find { it.barcode == barcode }

    fun upsert(product: Product) {
        val list = _products.value.toMutableList()
        val idx = list.indexOfFirst { it.id == product.id }
        if (idx >= 0) list[idx] = product else list.add(product)
        _products.value = list
        save()
    }

    fun delete(product: Product) {
        _products.value = _products.value.filter { it.id != product.id }
        save()
    }

    fun addStock(barcode: String, qty: Int) {
        if (qty <= 0) return
        val list = _products.value.toMutableList()
        val idx = list.indexOfFirst { it.barcode == barcode }
        if (idx < 0) return
        list[idx] = list[idx].copy(stock = (list[idx].stock + qty).coerceAtMost(99_999))
        _products.value = list
        save()
    }

    fun removeStock(barcode: String, qty: Int) {
        if (qty <= 0) return
        val list = _products.value.toMutableList()
        val idx = list.indexOfFirst { it.barcode == barcode }
        if (idx < 0 || list[idx].stock < qty) return
        list[idx] = list[idx].copy(stock = list[idx].stock - qty)
        _products.value = list
        save()
    }

    val categories: List<String>
        get() = _products.value.map { it.category }.distinct().sorted()

    val totalStockValue: Double
        get() = _products.value.sumOf { it.finalPrice * it.stock }
}
