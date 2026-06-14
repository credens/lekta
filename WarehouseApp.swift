import SwiftUI

@main
struct WarehouseApp: App {
    @StateObject private var productVM  = ProductViewModel()
    @StateObject private var checkoutVM = CheckoutViewModel()
    @StateObject private var cajaVM     = CajaViewModel()
    @StateObject private var authService = MPAuthService()

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    HomeView()
                        .environmentObject(productVM)
                        .environmentObject(checkoutVM)
                        .environmentObject(cajaVM)
                        .environmentObject(authService)
                } else {
                    MPConnectView()
                        .environmentObject(authService)
                }
            }
            .preferredColorScheme(.light)
            .animation(.easeInOut(duration: 0.4), value: authService.isAuthenticated)
        }
    }
}

// MARK: - Color extensions

extension Color {
    static let mpAmber   = Color(hex: "FF9A00")
    static let mpOrange  = Color(hex: "FF6B35")
    static let mpYellow  = Color(hex: "FFE600")
    static let mpCream   = Color(hex: "FFF8F0")
    static let mpSand    = Color(hex: "F5E6D3")
    static let mpBrown   = Color(hex: "8B5E3C")
    static let mpGreen   = Color(hex: "00B560")
    static let mpDanger  = Color(hex: "FF4444")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

// MARK: - Double formatting

extension Double {
    var arsCurrency: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: self)) ?? "$0"
    }
}
