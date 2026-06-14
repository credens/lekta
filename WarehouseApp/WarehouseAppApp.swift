import SwiftUI

@main
struct WarehouseAppApp: App {
    @StateObject private var authService         = MPAuthService()
    @StateObject private var cajaVM              = CajaViewModel()
    @StateObject private var productVM           = ProductViewModel()
    @StateObject private var checkoutVM          = CheckoutViewModel()
    @StateObject private var reportVM            = ReportViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var operadorVM          = OperadorViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(cajaVM)
                .environmentObject(productVM)
                .environmentObject(checkoutVM)
                .environmentObject(reportVM)
                .environmentObject(subscriptionManager)
                .environmentObject(operadorVM)
                .preferredColorScheme(.light)
        }
    }
}
