import SwiftUI

struct LaunchScreen: View {
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 24
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "FF9A00"), Color(hex: "FF6B35")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle decorative ring behind icon
            Circle()
                .strokeBorder(.white.opacity(0.15), lineWidth: 1.5)
                .frame(width: 140, height: 140)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            VStack(spacing: 20) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(.white)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                VStack(spacing: 6) {
                    Text("Lekta")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text("Tu negocio en el bolsillo")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                iconScale = 1.0
                iconOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                ringScale = 1.0
                ringOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.35)) {
                textOpacity = 1
                textOffset = 0
            }
        }
    }
}
