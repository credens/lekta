package com.lekta.app.models

import java.util.UUID

data class CartItem(
    val id: String = UUID.randomUUID().toString(),
    val product: Product,
    var quantity: Int
) {
    val subtotal: Double get() = product.finalPrice * quantity
}
