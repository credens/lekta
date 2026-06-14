package com.lekta.app.ui.reports

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.lekta.app.models.DailySummary
import com.lekta.app.ui.theme.*
import com.lekta.app.viewmodels.ProductViewModel
import com.lekta.app.viewmodels.ReportViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReportsScreen(
    onBack: () -> Unit,
    reportVM: ReportViewModel = hiltViewModel(),
    productVM: ProductViewModel = hiltViewModel()
) {
    val summaries by reportVM.summaries.collectAsState()
    val products by productVM.products.collectAsState()
    val lowStockProducts = products.filter { it.stock <= ReportViewModel.LOW_STOCK_THRESHOLD && it.stock > 0 }

    Scaffold(
        containerColor = MpCream,
        topBar = {
            TopAppBar(
                title = { Text("Reportes") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, null)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MpCream)
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Text("Resumen", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = MpBrown)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatCard("Hoy", "$${String.format("%,.0f", reportVM.todayTotal)}", Icons.Default.Today, Modifier.weight(1f))
                    StatCard("Semana", "$${String.format("%,.0f", reportVM.weekTotal)}", Icons.Default.DateRange, Modifier.weight(1f))
                }
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatCard("Mes", "$${String.format("%,.0f", reportVM.monthTotal)}", Icons.Default.CalendarMonth, Modifier.weight(1f))
                    StatCard("Ventas hoy", "${reportVM.todayCount}", Icons.Default.Receipt, Modifier.weight(1f))
                }
            }

            if (lowStockProducts.isNotEmpty()) {
                item {
                    Spacer(Modifier.height(8.dp))
                    Text("⚠️ Stock bajo", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = MpDanger)
                    Spacer(Modifier.height(8.dp))
                }
                items(lowStockProducts, key = { it.id }) { product ->
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        color = MpDanger.copy(alpha = 0.08f)
                    ) {
                        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(product.name, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = MpBrown)
                                Text(product.barcode, fontSize = 12.sp, color = MpBrownLight)
                            }
                            Text(
                                "${product.stock} uds",
                                fontWeight = FontWeight.Bold, color = MpDanger, fontSize = 14.sp
                            )
                        }
                    }
                }
            }

            if (summaries.isNotEmpty()) {
                item {
                    Spacer(Modifier.height(8.dp))
                    Text("Historial", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = MpBrown)
                    Spacer(Modifier.height(8.dp))
                }
                items(summaries, key = { it.id }) { summary ->
                    DailySummaryRow(summary)
                }
            }
        }
    }
}

@Composable
private fun StatCard(label: String, value: String, icon: ImageVector, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(14.dp),
        color = Color.White,
        shadowElevation = 2.dp
    ) {
        Column(Modifier.padding(16.dp)) {
            Icon(icon, null, tint = MpOrange, modifier = Modifier.size(24.dp))
            Spacer(Modifier.height(8.dp))
            Text(value, fontWeight = FontWeight.Bold, fontSize = 20.sp, color = MpBrown)
            Text(label, fontSize = 12.sp, color = MpBrownLight)
        }
    }
}

@Composable
private fun DailySummaryRow(summary: DailySummary) {
    val dateFormat = SimpleDateFormat("dd/MM HH:mm", Locale("es", "AR"))

    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        color = Color.White,
        shadowElevation = 1.dp
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(dateFormat.format(Date(summary.date)), fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = MpBrown)
                Text(
                    "${summary.cantidadVentas} ventas · ${summary.dominantMethod}",
                    fontSize = 12.sp, color = MpBrownLight
                )
                summary.operadorName?.let {
                    Text("Op: $it", fontSize = 11.sp, color = MpBrownLight)
                }
            }
            Text(
                "$${String.format("%,.0f", summary.totalVentas)}",
                fontWeight = FontWeight.Bold, fontSize = 16.sp, color = MpOrange
            )
        }
    }
}
