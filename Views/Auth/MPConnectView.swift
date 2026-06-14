import SwiftUI

struct MPConnectView: View {
    @EnvironmentObject var authService: MPAuthService
    @State private var windowAnchor: UIWindow?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "FF9A00"), Color(hex: "FF6B35")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo area
                VStack(spacing: 16) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(.white)
                    Text("WarehouseApp")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text("Tu negocio en el bolsillo")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                // Explicación
                VStack(spacing: 12) {
                    featureRow(icon: "qrcode", text: "Cobrar con QR de MercadoPago")
                    featureRow(icon: "chart.bar.fill", text: "Ver pagos y conciliar caja")
                    featureRow(icon: "lock.shield.fill", text: "Tus datos siempre seguros")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                // Botón conectar
                VStack(spacing: 16) {
                    Button {
                        guard let anchor = windowAnchor else { return }
                        authService.conectar(from: anchor)
                    } label: {
                        HStack(spacing: 12) {
                            if authService.isLoading {
                                ProgressView().tint(.mpOrange)
                            } else {
                                Image(systemName: "link.badge.plus")
                                    .font(.system(size: 20))
                            }
                            Text(authService.isLoading ? "Conectando..." : "Conectar con MercadoPago")
                                .font(.system(.headline, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(.white)
                        .foregroundStyle(.mpOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                    }
                    .disabled(authService.isLoading)

                    Text("Serás redirigido a MercadoPago para autorizar el acceso. Solo se hace una vez.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)

                // Error
                if let err = authService.errorMessage {
                    Text(err)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
            }
        }
        // Captura el UIWindow para pasárselo a ASWebAuthenticationSession
        .background(
            WindowAccessor { self.windowAnchor = $0 }
        )
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 28)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
        }
    }
}

// MARK: - WindowAccessor: UIViewRepresentable que devuelve el UIWindow activo

struct WindowAccessor: UIViewRepresentable {
    let callback: (UIWindow?) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            self.callback(uiView.window)
        }
    }
}
