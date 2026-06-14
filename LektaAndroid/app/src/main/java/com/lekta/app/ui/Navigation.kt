package com.lekta.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.lekta.app.services.MPAuthService
import com.lekta.app.ui.auth.MPConnectScreen
import com.lekta.app.ui.checkout.CheckoutScreen
import com.lekta.app.ui.cobrar.CobrarScreen
import com.lekta.app.ui.home.HomeScreen
import com.lekta.app.ui.products.InventarioScreen
import com.lekta.app.ui.products.ProductDetailScreen
import com.lekta.app.ui.reports.ReportsScreen

sealed class Screen(val route: String) {
    data object Connect : Screen("connect")
    data object Home : Screen("home")
    data object Cobrar : Screen("cobrar")
    data object Checkout : Screen("checkout")
    data object Inventario : Screen("inventario")
    data object ProductDetail : Screen("product_detail?barcode={barcode}") {
        fun createRoute(barcode: String = "") = "product_detail?barcode=$barcode"
    }
    data object Reports : Screen("reports")
}

@Composable
fun LektaNavigation(authService: MPAuthService) {
    val isAuthenticated by authService.isAuthenticated.collectAsState()
    val navController = rememberNavController()

    val startDestination = if (isAuthenticated) Screen.Home.route else Screen.Connect.route

    NavHost(navController = navController, startDestination = startDestination) {
        composable(Screen.Connect.route) {
            MPConnectScreen(authService = authService)
        }
        composable(Screen.Home.route) {
            HomeScreen(
                onNavigateCobrar = { navController.navigate(Screen.Cobrar.route) },
                onNavigateInventario = { navController.navigate(Screen.Inventario.route) },
                onNavigateReports = { navController.navigate(Screen.Reports.route) },
                onDesconectar = {
                    authService.desconectar()
                    navController.navigate(Screen.Connect.route) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            )
        }
        composable(Screen.Cobrar.route) {
            CobrarScreen(
                onNavigateCheckout = { navController.navigate(Screen.Checkout.route) },
                onBack = { navController.popBackStack() }
            )
        }
        composable(Screen.Checkout.route) {
            CheckoutScreen(onBack = { navController.popBackStack() })
        }
        composable(Screen.Inventario.route) {
            InventarioScreen(
                onNavigateDetail = { barcode ->
                    navController.navigate(Screen.ProductDetail.createRoute(barcode))
                },
                onBack = { navController.popBackStack() }
            )
        }
        composable(
            Screen.ProductDetail.route,
            arguments = listOf(navArgument("barcode") { type = NavType.StringType; defaultValue = "" })
        ) { backStackEntry ->
            val barcode = backStackEntry.arguments?.getString("barcode") ?: ""
            ProductDetailScreen(
                barcode = barcode,
                onBack = { navController.popBackStack() }
            )
        }
        composable(Screen.Reports.route) {
            ReportsScreen(onBack = { navController.popBackStack() })
        }
    }
}
