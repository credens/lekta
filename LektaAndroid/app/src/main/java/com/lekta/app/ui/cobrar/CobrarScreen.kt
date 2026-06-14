package com.lekta.app.ui.cobrar

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.lekta.app.models.Product
import com.lekta.app.services.BarcodeService
import com.lekta.app.ui.scanner.CameraPreview
import com.lekta.app.ui.theme.*
import com.lekta.app.viewmodels.CheckoutViewModel
import com.lekta.app.viewmodels.ProductViewModel
import com.lekta.app.viewmodels.ScannerViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CobrarScreen(
    onNavigateCheckout: () -> Unit,
    onBack: () -> Unit,
    scannerVM: ScannerViewModel = hiltViewModel(),
    checkoutVM: CheckoutViewModel = hiltViewModel(),
    productVM: ProductViewModel = hiltViewModel()
) {
    val scannedCode by scannerVM.scannedCode.collectAsState()
    val isRunning by scannerVM.isRunning.collectAsState()
    val products by productVM.products.collectAsState()
    val cartItems by checkoutVM.items.collectAsState()

    var cameraPermissionGranted by remember { mutableStateOf(false) }
    var showManualEntry by remember { mutableStateOf(false) }
    var toastMessage by remember { mutableStateOf<String?>(null) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        cameraPermissionGranted = granted
        if (granted) scannerVM.startSession()
    }

    LaunchedEffect(Unit) { permissionLauncher.launch(Manifest.permission.CAMERA) }

    LaunchedEffect(scannedCode) {
        val code = scannedCode ?: return@LaunchedEffect
        val result = BarcodeService.classify(code, products)
        when (result) {
            is com.lekta.app.models.ScanResult.ProductFound -> {
                checkoutVM.add(result.product)
                toastMessage = "+ ${result.product.name}"
                kotlinx.coroutines.delay(1500)
                scannerVM.resumeScanning()
            }
            is com.lekta.app.models.ScanResult.Unknown -> {
                toastMessage = "Producto no encontrado: $code"
                kotlinx.coroutines.delay(2000)
                scannerVM.resumeScanning()
            }
            else -> { scannerVM.resumeScanning() }
        }
        kotlinx.coroutines.delay(2000)
        toastMessage = null
    }

    Scaffold(
        containerColor = Color.Black,
        topBar = {
            TopAppBar(
                title = { Text("Cobrar", color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = Color.White)
                    }
                },
                actions = {
                    IconButton(onClick = { showManualEntry = true }) {
                        Icon(Icons.Default.Keyboard, null, tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Black.copy(alpha = 0.6f))
            )
        }
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (cameraPermissionGranted) {
                CameraPreview(
                    modifier = Modifier.fillMaxSize(),
                    isActive = isRunning,
                    onBarcodeDetected = { scannerVM.onBarcodeDetected(it) }
                )
            } else {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("Se necesita permiso de cámara", color = Color.White)
                }
            }

            // Scan overlay
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(250.dp, 150.dp)
                        .background(Color.Transparent)
                )
            }

            // Toast
            toastMessage?.let { msg ->
                Box(
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = 16.dp)
                        .background(MpGreen, RoundedCornerShape(12.dp))
                        .padding(horizontal = 20.dp, vertical = 12.dp)
                ) {
                    Text(msg, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                }
            }

            // Cart summary
            if (cartItems.isNotEmpty()) {
                Surface(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .padding(16.dp),
                    shape = RoundedCornerShape(20.dp),
                    color = Color.White,
                    shadowElevation = 8.dp,
                    onClick = onNavigateCheckout
                ) {
                    Row(
                        modifier = Modifier.padding(20.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                "${checkoutVM.itemCount} producto${if (checkoutVM.itemCount > 1) "s" else ""}",
                                fontWeight = FontWeight.SemiBold, color = MpBrown
                            )
                            Text(
                                "$${String.format("%,.2f", checkoutVM.total)}",
                                fontWeight = FontWeight.Bold, fontSize = 22.sp, color = MpOrange
                            )
                        }
                        Icon(Icons.Default.ShoppingCart, null, tint = MpOrange, modifier = Modifier.size(28.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Ver ticket ›", fontWeight = FontWeight.SemiBold, color = MpOrange)
                    }
                }
            }
        }
    }

    if (showManualEntry) {
        ManualEntryDialog(
            products = products,
            onDismiss = { showManualEntry = false },
            onProductSelected = { product ->
                checkoutVM.add(product)
                showManualEntry = false
                toastMessage = "+ ${product.name}"
            }
        )
    }
}

@Composable
private fun ManualEntryDialog(
    products: List<Product>,
    onDismiss: () -> Unit,
    onProductSelected: (Product) -> Unit
) {
    var query by remember { mutableStateOf("") }
    val focusManager = LocalFocusManager.current
    val filtered = products.filter {
        it.barcode.contains(query, ignoreCase = true) || it.name.contains(query, ignoreCase = true)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Buscar producto") },
        text = {
            Column {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    placeholder = { Text("Código o nombre") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = { focusManager.clearFocus() }),
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(12.dp))
                filtered.take(10).forEach { product ->
                    Surface(
                        onClick = { onProductSelected(product) },
                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                        shape = RoundedCornerShape(8.dp),
                        color = MpSand
                    ) {
                        Row(Modifier.padding(12.dp)) {
                            Column(Modifier.weight(1f)) {
                                Text(product.name, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                                Text(product.barcode, fontSize = 12.sp, color = MpBrownLight)
                            }
                            Text(
                                "$${String.format("%,.2f", product.finalPrice)}",
                                fontWeight = FontWeight.Bold, color = MpOrange
                            )
                        }
                    }
                }
                if (filtered.isEmpty() && query.isNotEmpty()) {
                    Text("Sin resultados", color = MpBrownLight, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(16.dp))
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("Cerrar") }
        }
    )
}
