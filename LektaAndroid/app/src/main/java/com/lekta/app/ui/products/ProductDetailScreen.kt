package com.lekta.app.ui.products

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Save
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.lekta.app.models.Product
import com.lekta.app.services.BarcodeService
import com.lekta.app.ui.theme.*
import com.lekta.app.viewmodels.ProductViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProductDetailScreen(
    barcode: String,
    onBack: () -> Unit,
    productVM: ProductViewModel = hiltViewModel()
) {
    val products by productVM.products.collectAsState()
    val existingProduct = products.find { it.barcode == barcode }
    val isEditing = existingProduct != null

    var name by remember { mutableStateOf(existingProduct?.name ?: "") }
    var barcodeField by remember { mutableStateOf(existingProduct?.barcode ?: barcode) }
    var price by remember { mutableStateOf(existingProduct?.price?.toString() ?: "") }
    var stock by remember { mutableStateOf(existingProduct?.stock?.toString() ?: "0") }
    var category by remember { mutableStateOf(existingProduct?.category ?: "") }
    var discount by remember { mutableStateOf((existingProduct?.discount?.times(100))?.toInt()?.toString() ?: "0") }

    Scaffold(
        containerColor = MpCream,
        topBar = {
            TopAppBar(
                title = { Text(if (isEditing) "Editar producto" else "Nuevo producto") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, null)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MpCream)
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 20.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Spacer(Modifier.height(8.dp))

            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Nombre del producto") },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            )

            OutlinedTextField(
                value = barcodeField,
                onValueChange = { barcodeField = it.filter { c -> c.isDigit() }.take(13) },
                label = { Text("Código de barras (EAN-13)") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth(),
                supportingText = {
                    if (barcodeField.length == 13) {
                        Text(
                            if (BarcodeService.isEAN13(barcodeField)) "EAN-13 válido ✓" else "Checksum inválido",
                            color = if (BarcodeService.isEAN13(barcodeField)) MpGreen else MpDanger,
                            fontSize = 12.sp
                        )
                    }
                }
            )

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = price,
                    onValueChange = { price = it },
                    label = { Text("Precio ($)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.weight(1f)
                )
                OutlinedTextField(
                    value = stock,
                    onValueChange = { stock = it.filter { c -> c.isDigit() }.take(5) },
                    label = { Text("Stock") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.weight(1f)
                )
            }

            OutlinedTextField(
                value = category,
                onValueChange = { category = it },
                label = { Text("Categoría") },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            )

            OutlinedTextField(
                value = discount,
                onValueChange = { discount = it.filter { c -> c.isDigit() }.take(2) },
                label = { Text("Descuento (%)") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            )

            val finalPrice = BarcodeService.sanitizedPrice(price) * (1 - (discount.toIntOrNull() ?: 0) / 100.0)
            if (price.isNotEmpty()) {
                Text(
                    "Precio final: $${String.format("%,.2f", finalPrice)}",
                    fontWeight = FontWeight.Bold, color = MpOrange, fontSize = 16.sp
                )
            }

            Spacer(Modifier.height(8.dp))

            Button(
                onClick = {
                    val product = Product(
                        id = existingProduct?.id ?: java.util.UUID.randomUUID().toString(),
                        barcode = barcodeField,
                        name = name.trim(),
                        price = BarcodeService.sanitizedPrice(price),
                        stock = BarcodeService.sanitizedStock(stock),
                        category = category.trim(),
                        discount = (discount.toIntOrNull() ?: 0) / 100.0
                    )
                    productVM.upsert(product)
                    onBack()
                },
                modifier = Modifier.fillMaxWidth().height(54.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = MpOrange),
                enabled = name.isNotBlank() && barcodeField.length == 13
            ) {
                Icon(Icons.Default.Save, null)
                Spacer(Modifier.width(8.dp))
                Text(if (isEditing) "Guardar cambios" else "Crear producto", fontWeight = FontWeight.Bold)
            }

            Spacer(Modifier.height(32.dp))
        }
    }
}
