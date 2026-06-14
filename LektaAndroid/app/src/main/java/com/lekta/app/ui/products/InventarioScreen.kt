package com.lekta.app.ui.products

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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.lekta.app.models.Product
import com.lekta.app.ui.theme.*
import com.lekta.app.viewmodels.ProductViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InventarioScreen(
    onNavigateDetail: (String) -> Unit,
    onBack: () -> Unit,
    productVM: ProductViewModel = hiltViewModel()
) {
    val products by productVM.products.collectAsState()
    var searchQuery by remember { mutableStateOf("") }

    val filtered = if (searchQuery.isEmpty()) products else products.filter {
        it.name.contains(searchQuery, ignoreCase = true) ||
                it.barcode.contains(searchQuery) ||
                it.category.contains(searchQuery, ignoreCase = true)
    }

    Scaffold(
        containerColor = MpCream,
        topBar = {
            TopAppBar(
                title = { Text("Inventario") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, null)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MpCream)
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { onNavigateDetail("") },
                containerColor = MpOrange,
                contentColor = Color.White
            ) {
                Icon(Icons.Default.Add, contentDescription = "Nuevo producto")
            }
        }
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = { Text("Buscar por nombre, código o categoría") },
                leadingIcon = { Icon(Icons.Default.Search, null) },
                singleLine = true,
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            )

            Row(
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("${filtered.size} productos", fontSize = 13.sp, color = MpBrownLight)
                Spacer(Modifier.weight(1f))
                Text(
                    "Valor: $${String.format("%,.0f", productVM.totalStockValue)}",
                    fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MpOrange
                )
            }

            LazyColumn(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(filtered, key = { it.id }) { product ->
                    ProductRow(
                        product = product,
                        onClick = { onNavigateDetail(product.barcode) },
                        onDelete = { productVM.delete(product) }
                    )
                }
            }
        }
    }
}

@Composable
private fun ProductRow(product: Product, onClick: () -> Unit, onDelete: () -> Unit) {
    var showDeleteConfirm by remember { mutableStateOf(false) }

    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        color = Color.White,
        shadowElevation = 2.dp,
        onClick = onClick
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text(product.name, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, color = MpBrown)
                Text(product.barcode, fontSize = 12.sp, color = MpBrownLight)
                if (product.category.isNotEmpty()) {
                    Text(product.category, fontSize = 11.sp, color = MpOrange)
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    "$${String.format("%,.2f", product.finalPrice)}",
                    fontWeight = FontWeight.Bold, color = MpOrange
                )
                Text(
                    "Stock: ${product.stock}",
                    fontSize = 12.sp,
                    color = if (product.stock <= 5) MpDanger else MpBrownLight,
                    fontWeight = if (product.stock <= 5) FontWeight.Bold else FontWeight.Normal
                )
            }
            IconButton(onClick = { showDeleteConfirm = true }) {
                Icon(Icons.Default.Delete, null, tint = MpDanger.copy(alpha = 0.6f), modifier = Modifier.size(20.dp))
            }
        }
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("Eliminar producto") },
            text = { Text("¿Eliminar \"${product.name}\" del inventario?") },
            confirmButton = {
                TextButton(onClick = { showDeleteConfirm = false; onDelete() }) {
                    Text("Eliminar", color = MpDanger)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) { Text("Cancelar") }
            }
        )
    }
}
