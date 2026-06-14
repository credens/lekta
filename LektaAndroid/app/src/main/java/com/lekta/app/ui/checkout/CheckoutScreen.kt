package com.lekta.app.ui.checkout

import android.graphics.Bitmap
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import com.lekta.app.models.CartItem
import com.lekta.app.models.PaymentMethod
import com.lekta.app.ui.theme.*
import com.lekta.app.viewmodels.CajaViewModel
import com.lekta.app.viewmodels.CheckoutViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CheckoutScreen(
    onBack: () -> Unit,
    checkoutVM: CheckoutViewModel = hiltViewModel(),
    cajaVM: CajaViewModel = hiltViewModel()
) {
    val items by checkoutVM.items.collectAsState()
    var selectedMethod by remember { mutableStateOf(PaymentMethod.QR_MP) }
    var showConfirmation by remember { mutableStateOf(false) }

    Scaffold(
        containerColor = MpCream,
        topBar = {
            TopAppBar(
                title = { Text("Checkout") },
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
        ) {
            LazyColumn(modifier = Modifier.weight(1f)) {
                items(items, key = { it.id }) { item ->
                    CartItemRow(
                        item = item,
                        onUpdateQty = { qty -> checkoutVM.updateQty(item, qty) },
                        onRemove = { checkoutVM.remove(item) }
                    )
                }
            }

            HorizontalDivider(Modifier.padding(vertical = 12.dp))

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Total", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = MpBrown)
                Text(
                    "$${String.format("%,.2f", checkoutVM.total)}",
                    fontWeight = FontWeight.Bold, fontSize = 24.sp, color = MpOrange
                )
            }

            Spacer(Modifier.height(16.dp))

            Text("Método de pago", fontWeight = FontWeight.SemiBold, color = MpBrown)
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                PaymentMethod.entries.forEach { method ->
                    FilterChip(
                        selected = selectedMethod == method,
                        onClick = { selectedMethod = method },
                        label = { Text(method.label) },
                        leadingIcon = { Icon(method.icon, null, modifier = Modifier.size(18.dp)) }
                    )
                }
            }

            Spacer(Modifier.height(20.dp))

            Button(
                onClick = {
                    cajaVM.registrarVenta(checkoutVM.total, selectedMethod)
                    showConfirmation = true
                },
                modifier = Modifier.fillMaxWidth().height(54.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(containerColor = MpGreen),
                enabled = items.isNotEmpty()
            ) {
                Icon(Icons.Default.Check, null)
                Spacer(Modifier.width(8.dp))
                Text("Confirmar cobro", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }

            Spacer(Modifier.height(24.dp))
        }
    }

    if (showConfirmation) {
        AlertDialog(
            onDismissRequest = {
                showConfirmation = false
                checkoutVM.clear()
                onBack()
            },
            icon = { Icon(Icons.Default.CheckCircle, null, tint = MpGreen, modifier = Modifier.size(48.dp)) },
            title = { Text("Venta registrada", textAlign = TextAlign.Center) },
            text = {
                Text(
                    "Total: $${String.format("%,.2f", checkoutVM.total)}\nMétodo: ${selectedMethod.label}",
                    textAlign = TextAlign.Center
                )
            },
            confirmButton = {
                Button(onClick = {
                    showConfirmation = false
                    checkoutVM.clear()
                    onBack()
                }) { Text("Listo") }
            }
        )
    }
}

@Composable
private fun CartItemRow(item: CartItem, onUpdateQty: (Int) -> Unit, onRemove: () -> Unit) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        shape = RoundedCornerShape(14.dp),
        color = Color.White,
        shadowElevation = 2.dp
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text(item.product.name, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, color = MpBrown)
                Text(
                    "$${String.format("%,.2f", item.product.finalPrice)} c/u",
                    fontSize = 13.sp, color = MpBrownLight
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { if (item.quantity > 1) onUpdateQty(item.quantity - 1) else onRemove() }) {
                    Icon(Icons.Default.Remove, null, tint = MpOrange, modifier = Modifier.size(20.dp))
                }
                Text("${item.quantity}", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = MpBrown)
                IconButton(onClick = { onUpdateQty(item.quantity + 1) }) {
                    Icon(Icons.Default.Add, null, tint = MpOrange, modifier = Modifier.size(20.dp))
                }
            }
            Text(
                "$${String.format("%,.2f", item.subtotal)}",
                fontWeight = FontWeight.Bold, color = MpOrange, modifier = Modifier.padding(start = 8.dp)
            )
        }
    }
}

fun generateQRBitmap(content: String, size: Int = 512): Bitmap {
    val writer = QRCodeWriter()
    val bitMatrix = writer.encode(content, BarcodeFormat.QR_CODE, size, size)
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.RGB_565)
    for (x in 0 until size) {
        for (y in 0 until size) {
            bitmap.setPixel(x, y, if (bitMatrix[x, y]) android.graphics.Color.BLACK else android.graphics.Color.WHITE)
        }
    }
    return bitmap
}
