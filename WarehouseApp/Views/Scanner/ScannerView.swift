import SwiftUI

enum ScanMode: String, CaseIterable {
    case checkout = "EAN-13"
    case addStock = "Stock +"
    case removeStock = "Stock −"
}

struct ScannerView: View {
    @EnvironmentObject var productVM: ProductViewModel
    @EnvironmentObject var checkoutVM: CheckoutViewModel
    @StateObject private var scannerVM = ScannerViewModel()

    @State private var scanMode: ScanMode = .checkout
    @State private var result: ScanResult?
    @State private var scanLineOffset: CGFloat = 0
    @State private var showCreateProduct = false
    @State private var pendingBarcode: String?
    @State private var addStockQty: Int = 1
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Camera fullscreen
            CameraPreview(session: scannerVM.session)
                .ignoresSafeArea()

            // Scan visor overlay
            scanOverlay

            // Bottom sheet
            bottomSheet
        }
        .onAppear { scannerVM.startSession() }
        .onDisappear { scannerVM.stopSession() }
        .onChange(of: scannerVM.scannedCode) { _, code in
            guard let code else { return }
            withAnimation(.spring()) {
                result = BarcodeService.classify(code, products: productVM.products)
            }
        }
        .sheet(isPresented: $showCreateProduct) {
            if let barcode = pendingBarcode {
                NavigationStack {
                    ProductDetailView(barcode: barcode)
                        .environmentObject(productVM)
                }
            }
        }
    }

    // MARK: - Scan overlay

    private var scanOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.7
            let h: CGFloat = 160
            let _ = (geo.size.width - w) / 2
            let y = (geo.size.height - h) / 2 - 60

            ZStack {
                // Dimmed background
                Color.black.opacity(0.5).ignoresSafeArea()
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .frame(width: w, height: h)
                                    .offset(x: 0, y: y - geo.size.height / 2 + h / 2)
                                    .blendMode(.destinationOut)
                            )
                    )

                // Scan frame corners
                ScanFrame(width: w, height: h)
                    .position(x: geo.size.width / 2, y: y + h / 2)

                // Animated scan line
                Rectangle()
                    .fill(Color.mpYellow.opacity(0.8))
                    .frame(width: w - 8, height: 2)
                    .offset(y: scanLineOffset)
                    .position(x: geo.size.width / 2, y: y + h / 2)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: scanLineOffset)

                // Hint label
                VStack {
                    Spacer()
                        .frame(height: y + h + 16)
                    Text("Apuntá al código de barras o QR")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }

                // Mode pills
                VStack {
                    Spacer()
                        .frame(height: y + h + 44)
                    modePills
                }
            }
            .onAppear {
                scanLineOffset = -(h / 2 - 8)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scanLineOffset = h / 2 - 8
                }
            }
        }
    }

    private var modePills: some View {
        HStack(spacing: 8) {
            ForEach(ScanMode.allCases, id: \.self) { mode in
                Button(mode.rawValue) {
                    scanMode = mode
                }
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(scanMode == mode ? Color.mpOrange : Color.white.opacity(0.2))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Bottom sheet

    private var bottomSheet: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.vertical, 10)

            if let result {
                resultCard(result)
            } else {
                Text("Esperando escaneo...")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func resultCard(_ result: ScanResult) -> some View {
        switch result {
        case .product(let product):
            productCard(product)
        case .mercadoPagoQR(let url):
            mpQRCard(url)
        case .unknown(let code):
            unknownCard(code)
        }
    }

    private func productCard(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Category icon
                Text(categoryEmoji(product.category))
                    .font(.largeTitle)
                    .frame(width: 56, height: 56)
                    .background(Color.mpSand)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.system(.headline, design: .rounded))
                    Text(product.barcode)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(product.finalPrice.arsCurrency)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.mpBrown)
                        Spacer()
                        Label("\(product.stock) u.", systemImage: "shippingbox")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(product.stock < 5 ? .mpDanger : .secondary)
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    handleStockAction(product: product)
                } label: {
                    Label("+ Stock", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .padding(.vertical, 12)
                        .background(Color.mpSand)
                        .foregroundStyle(.mpBrown)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    checkoutVM.add(product: product)
                    scannerVM.resumeScanning()
                    self.result = nil
                } label: {
                    Label("Cobrar", systemImage: "creditcard")
                        .frame(maxWidth: .infinity)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .padding(.vertical, 12)
                        .background(LinearGradient(colors: [.mpAmber, .mpOrange], startPoint: .leading, endPoint: .trailing))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .mpOrange.opacity(0.4), radius: 8, y: 4)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func unknownCard(_ code: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                    Text("Código no encontrado")
                        .font(.system(.headline, design: .rounded))
                    Text(code)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 12) {
                Button("Volver a escanear") {
                    self.result = nil
                    scannerVM.resumeScanning()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.mpSand)
                .foregroundStyle(.mpBrown)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Crear producto") {
                    pendingBarcode = code
                    showCreateProduct = true
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(LinearGradient(colors: [.mpAmber, .mpOrange], startPoint: .leading, endPoint: .trailing))
                .foregroundStyle(.white)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .mpOrange.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func mpQRCard(_ url: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "qrcode")
                    .font(.title2)
                    .foregroundStyle(.mpOrange)
                VStack(alignment: .leading) {
                    Text("QR de MercadoPago")
                        .font(.system(.headline, design: .rounded))
                    Text(url)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            Button("Continuar") {
                self.result = nil
                scannerVM.resumeScanning()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(LinearGradient(colors: [.mpAmber, .mpOrange], startPoint: .leading, endPoint: .trailing))
            .foregroundStyle(.white)
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .mpOrange.opacity(0.4), radius: 8, y: 4)
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private func handleStockAction(product: Product) {
        switch scanMode {
        case .addStock:
            productVM.addStock(barcode: product.barcode, qty: 1)
        case .removeStock:
            productVM.removeStock(barcode: product.barcode, qty: 1)
        default:
            break
        }
        self.result = nil
        scannerVM.resumeScanning()
    }

    private func categoryEmoji(_ category: String) -> String {
        let map: [String: String] = [
            "Electrónica": "📱", "Ropa": "👕", "Alimentos": "🍎",
            "Herramientas": "🔧", "Libros": "📚", "Bebidas": "🥤"
        ]
        return map[category] ?? "📦"
    }
}

// MARK: - Scan frame corners

struct ScanFrame: View {
    let width: CGFloat
    let height: CGFloat
    let cornerLength: CGFloat = 24
    let lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            // Top-left
            corner().offset(x: -width / 2, y: -height / 2)
            corner().rotationEffect(.degrees(90)).offset(x: width / 2, y: -height / 2)
            corner().rotationEffect(.degrees(180)).offset(x: width / 2, y: height / 2)
            corner().rotationEffect(.degrees(270)).offset(x: -width / 2, y: height / 2)
        }
    }

    func corner() -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: cornerLength))
            p.addLine(to: .zero)
            p.addLine(to: CGPoint(x: cornerLength, y: 0))
        }
        .stroke(Color.mpYellow, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
}
