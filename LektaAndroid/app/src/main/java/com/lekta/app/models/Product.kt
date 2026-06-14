package com.lekta.app.models

import java.util.UUID

data class Product(
    val id: String = UUID.randomUUID().toString(),
    val barcode: String,
    val name: String,
    val price: Double,
    var stock: Int,
    val variants: List<Variant> = emptyList(),
    val discount: Double = 0.0,
    val category: String = ""
) {
    val finalPrice: Double get() = price * (1 - discount)

    data class Variant(
        val id: String = UUID.randomUUID().toString(),
        val name: String,
        val value: String,
        val priceDelta: Double,
        val stock: Int
    )
}
