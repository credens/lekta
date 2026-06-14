package com.lekta.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LektaColorScheme = lightColorScheme(
    primary = MpOrange,
    onPrimary = androidx.compose.ui.graphics.Color.White,
    primaryContainer = MpSand,
    onPrimaryContainer = MpBrown,
    secondary = MpAmber,
    onSecondary = androidx.compose.ui.graphics.Color.White,
    tertiary = MpGreen,
    onTertiary = androidx.compose.ui.graphics.Color.White,
    background = MpCream,
    onBackground = MpBrown,
    surface = androidx.compose.ui.graphics.Color.White,
    onSurface = MpBrown,
    surfaceVariant = MpSand,
    onSurfaceVariant = MpBrownLight,
    error = MpDanger,
    onError = androidx.compose.ui.graphics.Color.White,
    outline = MpBrownLight.copy(alpha = 0.3f)
)

@Composable
fun LektaTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LektaColorScheme,
        typography = LektaTypography,
        content = content
    )
}
