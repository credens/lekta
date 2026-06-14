import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "FF9A00"), Color(hex: "FF6B35")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(.white)

                Text("WarehouseApp")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                Text("Tu negocio en el bolsillo")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
