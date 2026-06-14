package com.lekta.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.lifecycleScope
import com.lekta.app.services.MPAuthService
import com.lekta.app.ui.LektaNavigation
import com.lekta.app.ui.theme.LektaTheme
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var authService: MPAuthService

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleOAuthCallback(intent)

        setContent {
            LektaTheme {
                LektaNavigation(authService = authService)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleOAuthCallback(intent)
    }

    private fun handleOAuthCallback(intent: Intent) {
        val uri = intent.data ?: return
        if (uri.scheme != Config.CALLBACK_SCHEME || uri.host != "auth") return

        if (authService.handleCallback(uri)) {
            val code = authService.getCodeFromUri(uri) ?: return
            lifecycleScope.launch {
                authService.exchangeCode(code)
            }
        }
    }
}
