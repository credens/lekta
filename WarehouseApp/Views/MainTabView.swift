import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var productVM: ProductViewModel
    @EnvironmentObject var checkoutVM: CheckoutViewModel

    var body: some View {
        TabView {
            ScannerView()
                .tabItem {
                    Label("Escanear", systemImage: "barcode.viewfinder")
                }

            ProductListView()
                .tabItem {
                    Label("Productos", systemImage: "shippingbox")
                }

            CheckoutView()
                .tabItem {
                    Label("Cobrar", systemImage: "creditcard")
                }
                .badge(checkoutVM.itemCount > 0 ? checkoutVM.itemCount : 0)
        }
        .tint(.mpOrange)
    }
}
