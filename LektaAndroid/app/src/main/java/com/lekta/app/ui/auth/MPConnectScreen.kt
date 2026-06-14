package com.lekta.app.ui.auth

import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lekta.app.services.MPAuthService
import com.lekta.app.ui.theme.MpAmber
import com.lekta.app.ui.theme.MpOrange

@Composable
fun MPConnectScreen(authService: MPAuthService) {
    val isLoading by authService.isLoading.collectAsState()
    val errorMessage by authService.errorMessage.collectAsState()
    val context = LocalContext.current

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.linearGradient(listOf(MpAmber, MpOrange)))
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.weight(1f))

            Icon(
                Icons.Default.QrCode,
                contentDescription = null,
                modifier = Modifier.size(80.dp),
                tint = Color.White
            )
            Spacer(Modifier.height(16.dp))
            Text(
                "Lekta",
                fontSize = 36.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Text(
                "Tu negocio en el bolsillo",
                fontSize = 15.sp,
                color = Color.White.copy(alpha = 0.8f)
            )

            Spacer(Modifier.weight(1f))

            FeatureRow(Icons.Default.QrCode, "Cobrar con QR de MercadoPago")
            Spacer(Modifier.height(12.dp))
            FeatureRow(Icons.Default.ShowChart, "Ver pagos y conciliar caja")
            Spacer(Modifier.height(12.dp))
            FeatureRow(Icons.Default.Lock, "Tus datos siempre seguros")

            Spacer(Modifier.height(40.dp))

            Button(
                onClick = {
                    val intent = authService.buildAuthIntent()
                    (context as? Activity)?.startActivity(intent)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(18.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.White,
                    contentColor = MpOrange
                ),
                enabled = !isLoading
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = MpOrange,
                        strokeWidth = 2.dp
                    )
                } else {
                    Text("Conectar con MercadoPago", fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                }
            }

            errorMessage?.let { msg ->
                Spacer(Modifier.height(12.dp))
                Text(msg, color = Color.White, fontSize = 13.sp, textAlign = TextAlign.Center)
            }

            Spacer(Modifier.height(14.dp))

            Text(
                "Continuar sin MercadoPago",
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable { authService.skipAuthentication() }
                    .padding(12.dp)
            )

            Spacer(Modifier.height(16.dp))

            Text(
                "Serás redirigido a MercadoPago para autorizar el acceso. Solo se hace una vez.",
                color = Color.White.copy(alpha = 0.5f),
                fontSize = 12.sp,
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(52.dp))
        }
    }
}

@Composable
private fun FeatureRow(icon: ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(24.dp))
        Spacer(Modifier.width(14.dp))
        Text(text, color = Color.White.copy(alpha = 0.9f), fontSize = 15.sp)
    }
}
