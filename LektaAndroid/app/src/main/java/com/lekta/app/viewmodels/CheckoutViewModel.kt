package com.lekta.app.viewmodels

import androidx.lifecycle.ViewModel
import com.lekta.app.models.CartItem
import com.lekta.app.models.Product
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject

@HiltViewModel
class CheckoutViewModel @Inject constructor() : ViewModel() {

    private val _items = MutableStateFlow<List<CartItem>>(emptyList())
    val items: StateFlow<List<CartItem>> = _items

    fun add(product: Product) {
        val list = _items.value.toMutableList()
        val idx = list.indexOfFirst { it.product.id == product.id }
        if (idx >= 0) {
            list[idx] = list[idx].copy(quantity = list[idx].quantity + 1)
        } else {
            list.add(CartItem(product = product, quantity = 1))
        }
        _items.value = list
    }

    fun remove(item: CartItem) {
        _items.value = _items.value.filter { it.id != item.id }
    }

    fun updateQty(item: CartItem, qty: Int) {
        val list = _items.value.toMutableList()
        val idx = list.indexOfFirst { it.id == item.id }
        if (idx < 0) return
        if (qty <= 0) list.removeAt(idx) else list[idx] = list[idx].copy(quantity = qty)
        _items.value = list
    }

    fun clear() {
        _items.value = emptyList()
    }

    val total: Double get() = _items.value.sumOf { it.subtotal }
    val itemCount: Int get() = _items.value.sumOf { it.quantity }

    val subtotalBeforeDiscount: Double
        get() = _items.value.sumOf { it.product.price * it.quantity }

    val discount: Double get() = subtotalBeforeDiscount - total
}
