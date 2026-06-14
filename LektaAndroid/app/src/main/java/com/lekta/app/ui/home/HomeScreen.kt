package com.lekta.app.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.lekta.app.ui.theme.*
import com.lekta.app.viewmodels.CajaEstado
import com.lekta.app.viewmodels.CajaViewModel
import com.lekta.app.viewmodels.OperadorViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onNavigateCobrar: () -> Unit,
    onNavigateInventario: () -> Unit,
    onNavigateReports: () -> Unit,
    onDesconectar: () -> Unit,
    cajaVM: CajaViewModel = hiltViewModel(),
    operadorVM: OperadorViewModel = hiltViewModel()
) {
    val estado by cajaVM.estado.collectAsState()
    val totalVentas by cajaVM.totalVentas.collectAsState()
    val cantidadVentas by cajaVM.cantidadVentas.collectAsState()
    val operadorName by cajaVM.currentOperadorName.collectAsState()
    var showMenu by remember { mutableStateOf(false) }
    val estaAbierta = estado is CajaEstado.Abierta

    val dateFormat = remember { SimpleDateFormat("EEEE, d 'de' MMMM", Locale("es", "AR")) }
    val today = remember { dateFormat.format(Date()).replaceFirstChar { it.uppercase() } }

    Scaffold(
        containerColor = MpCream,
        topBar = {
            TopAppBar(
                title = {},
                actions = {
                    IconButton(onClick = { showMenu = true }) {
                        Icon(Icons.Default.MoreVert, contentDescription = "Menú", tint = MpBrown)
                    }
                    DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                        DropdownMenuItem(
                            text = { Text("Desconectar MercadoPago", color = MpDanger) },
                            onClick = { showMenu = false; onDesconectar() },
                            leadingIcon = { Icon(Icons.Default.LinkOff, null, tint = MpDanger) }
                        )
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
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("🏪 Mi Negocio", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = MpBrown)
            Spacer(Modifier.height(4.dp))
            Text(today, fontSize = 14.sp, color = MpBrownLight)
            Spacer(Modifier.height(12.dp))

            Surface(
                shape = RoundedCornerShape(20.dp),
                color = if (estaAbierta) MpGreen else Color.Gray,
                modifier = Modifier.padding(bottom = 8.dp)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        if (estaAbierta) Icons.Default.LockOpen else Icons.Default.Lock,
                        null, tint = Color.White, modifier = Modifier.size(14.dp)
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(
                        if (estaAbierta) "Caja abierta" else "Caja cerrada",
                        color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold
                    )
                }
            }

            operadorName?.let { name ->
                Text("Operador: $name", fontSize = 13.sp, color = MpBrownLight)
            }

            if (estaAbierta) {
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                    StatChip("Ventas", cantidadVentas.toString())
                    StatChip("Total", "$${String.format("%,.0f", totalVentas)}")
                }
            }

            Spacer(Modifier.height(24.dp))

            if (!estaAbierta) {
                HomeActionButton(
                    icon = Icons.Default.AttachMoney,
                    title = "Abrir Caja",
                    subtitle = "Habilita cobros y conecta con MP",
                    containerColor = MpGreen,
                    contentColor = Color.White,
                    onClick = {
                        val defaultOp = operadorVM.activeOperadores.firstOrNull()
                            ?: com.lekta.app.models.Operador(name = "Admin", pinHash = "")
                        cajaVM.abrirCaja(defaultOp)
                    }
                )
            }

            HomeActionButton(
                icon = Icons.Default.CameraAlt,
                title = "Cobrar",
                subtitle = "Escanear y procesar ventas",
                containerColor = if (estaAbierta) MpOrange else Color.Gray.copy(alpha = 0.3f),
                contentColor = if (estaAbierta) Color.White else Color.Gray,
                enabled = estaAbierta,
                onClick = onNavigateCobrar
            )

            if (estaAbierta) {
                HomeActionButton(
                    icon = Icons.Default.Lock,
                    title = "Cerrar Caja",
                    subtitle = "Cierra sesión y concilia MP",
                    containerColor = Color.White,
                    contentColor = MpBrown,
                    onClick = { cajaVM.cerrarCaja() }
                )
            }

            HomeActionButton(
                icon = Icons.Default.Inventory2,
                title = "Inventario",
                subtitle = "Productos, stock y precios",
                containerColor = Color.White,
                contentColor = MpBrown,
                onClick = onNavigateInventario
            )

            HomeActionButton(
                icon = Icons.Default.BarChart,
                title = "Reportes",
                subtitle = "Ventas y resumen del día",
                containerColor = Color.White,
                contentColor = MpBrown,
                onClick = onNavigateReports
            )
        }
    }
}

@Composable
private fun HomeActionButton(
    icon: ImageVector,
    title: String,
    subtitle: String,
    containerColor: Color,
    contentColor: Color,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 7.dp)
            .shadow(6.dp, RoundedCornerShape(18.dp)),
        shape = RoundedCornerShape(18.dp),
        color = containerColor,
        onClick = onClick,
        enabled = enabled
    ) {
        Row(
            modifier = Modifier.padding(18.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(icon, null, tint = contentColor, modifier = Modifier.size(30.dp))
            Spacer(Modifier.width(16.dp))
            Column(Modifier.weight(1f)) {
                Text(title, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, color = contentColor)
                Text(subtitle, fontSize = 12.sp, color = contentColor.copy(alpha = 0.7f))
            }
            Text("›", fontSize = 20.sp, color = contentColor.copy(alpha = 0.5f))
        }
    }
}

@Composable
private fun StatChip(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, fontWeight = FontWeight.Bold, fontSize = 18.sp, color = MpOrange)
        Text(label, fontSize = 12.sp, color = MpBrownLight)
    }
}
