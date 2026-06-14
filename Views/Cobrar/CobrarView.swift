import SwiftUI

struct CobrarView: View {
    @EnvironmentObject var productVM: ProductViewModel
    @EnvironmentObject var checkoutVM: CheckoutViewModel
    @EnvironmentObject var cajaVM: CajaViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var scannerVM = ScannerViewModel()

    @State private var showManualEntry = false
    @State private var showTicket = false
    @State private var showCheckout = false
    @State private var toast: ToastItem?

    var body: some View {
        ZStack {
            // Cámara fullscreen
            CameraPreview(session: scannerVM.session)
                .ignoresSafeArea()

            // Overlay oscuro + visor
            ScanOverlayView()

            // Toast de producto agregado
            if let t = toast {
                ScanToast(item: t)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
            }

            // Barra inferior
            bottomBar
        }
        .ignoresSafeArea()
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    scannerVM.stopSession()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Inicio")
                    }
                    .foregroundStyle(.white)
                    .font(.system(.body, design: .rounded))
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Escanear")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { scannerVM.startSession() }
        .onDisappear { scannerVM.stopSession() }
        .onChange(of: scannerVM.scannedCode) { code in
            guard let code else { return }
            handleScan(code)
        }
        .sheet(isPresented: $showManualEntry) {
            ManualEntrySheet { product, qty in
                addToCart(product: product, qty: qty)
            }
            .environmentObject(productVM)
        }
        .onChange(of: showManualEntry) { isOpen in
            if !isOpen { scannerVM.resumeScanning() }
        }
        .sheet(isPresented: $showTicket) {
            TicketSheet()
                .environmentObject(checkoutVM)
                .environmentObject(productVM)
        }
        .onChange(of: showTicket) { isOpen in
            if !isOpen { scannerVM.resumeScanning() }
        }
        .sheet(isPresented: $showCheckout) {
            NavigationStack {
                CheckoutView()
                    .environmentObject(checkoutVM)
                    .environmentObject(productVM)
                    .environmentObject(cajaVM)
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                // Manual entry
                Button {
                    scannerVM.stopSession()
                    showManualEntry = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 20))
                        Text("Manual")
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 56)
                    .background(.ultraThinMaterial.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Ver ticket
                Button {
                    scannerVM.stopSession()
                    showTicket = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 18))
                        if checkoutVM.itemCount > 0 {
                            Text("\(checkoutVM.itemCount) ítem\(checkoutVM.itemCount == 1 ? "" : "s")")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        } else {
                            Text("Ticket vacío")
                                .font(.system(.subheadline, design: .rounded))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(.ultraThinMaterial.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Cobrar
                Button {
                    guard checkoutVM.itemCount > 0 else { return }
                    scannerVM.stopSession()
                    showCheckout = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 18))
                        Text(checkoutVM.total.arsCurrency)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 56)
                    .background(
                        checkoutVM.itemCount > 0
                            ? AnyShapeStyle(LinearGradient(colors: [.mpAmber, .mpOrange], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.white.opacity(0.2))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: checkoutVM.itemCount > 0 ? .mpOrange.opacity(0.5) : .clear, radius: 8, y: 4)
                }
                .disabled(checkoutVM.itemCount == 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Logic

    private func handleScan(_ code: String) {
        let result = BarcodeService.classify(code, products: productVM.products)
        switch result {
        case .product(let p):
            addToCart(product: p, qty: 1)
        case .unknown:
            showToast(ToastItem(icon: "questionmark.circle", message: "Código no encontrado", isError: true))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                scannerVM.resumeScanning()
            }
        case .mercadoPagoQR:
            scannerVM.resumeScanning()
        }
    }

    private func addToCart(product: Product, qty: Int) {
        for _ in 0..<qty { checkoutVM.add(product: product) }
        showToast(ToastItem(
            icon: "checkmark.circle.fill",
            message: "\(product.name) ×\(qty) — \((product.finalPrice * Double(qty)).arsCurrency)",
            isError: false
        ))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring()) { toast = nil }
            scannerVM.resumeScanning()
        }
    }

    private func showToast(_ item: ToastItem) {
        withAnimation(.spring(response: 0.3)) { toast = item }
    }
}

// MARK: - Toast

struct ToastItem: Equatable {
    let icon: String
    let message: String
    let isError: Bool
}

struct ScanToast: View {
    let item: ToastItem
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .foregroundStyle(item.isError ? .mpDanger : .mpGreen)
                .font(.system(size: 18))
            Text(item.message)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, 24)
    }
}

// MARK: - Scan overlay (reutilizable, sin lógica)

struct ScanOverlayView: View {
    @State private var scanLineOffset: CGFloat = -67

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.72
            let h: CGFloat = 160
            let cx = geo.size.width / 2
            let cy = geo.size.height * 0.42

            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .mask(
                        Rectangle().overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .frame(width: w, height: h)
                                .position(x: cx, y: cy)
                                .blendMode(.destinationOut)
                        )
                    )

                ScanFrame(width: w, height: h)
                    .position(x: cx, y: cy)

                Rectangle()
                    .fill(Color.mpYellow.opacity(0.85))
                    .frame(width: w - 10, height: 2)
                    .position(x: cx, y: cy + scanLineOffset)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: scanLineOffset)

                VStack {
                    Spacer().frame(height: cy + h / 2 + 18)
                    Text("Apuntá al código de barras")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .onAppear { scanLineOffset = 67 }
        }
    }
}

// MARK: - Manual Entry Sheet

struct ManualEntrySheet: View {
    @EnvironmentObject var productVM: ProductViewModel
    @Environment(\.dismiss) private var dismiss

    let onAdd: (Product, Int) -> Void

    @State private var code = ""
    @State private var qty = 1
    @State private var found: Product?
    @State private var notFound = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Barcode input
                VStack(alignment: .leading, spacing: 8) {
                    Text("CÓDIGO DE BARRAS")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)

                    HStack {
                        Image(systemName: "barcode")
                            .foregroundStyle(.secondary)
                        TextField("Ingresá el código EAN-13", text: $code)
                            .keyboardType(.numberPad)
                            .font(.system(.body, design: .monospaced))
                            .focused($focused)
                            .onChange(of: code) { val in
                                // Strip non-numeric chars silently
                                let numeric = val.filter(\.isNumber)
                                if numeric != val { code = numeric; return }
                                notFound = false
                                found = nil
                                if numeric.count == 13 {
                                    if let p = productVM.find(barcode: numeric) {
                                        found = p
                                    } else {
                                        notFound = true
                                    }
                                }
                            }
                        if !code.isEmpty {
                            Button { code = ""; found = nil; notFound = false } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.mpSand)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if notFound {
                        Label("Código no encontrado en el inventario", systemImage: "exclamationmark.circle")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.mpDanger)
                    }
                }

                // Producto encontrado
                if let p = found {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Text(categoryEmoji(p.category))
                                .font(.title2)
                                .frame(width: 52, height: 52)
                                .background(Color.mpSand)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.name)
                                    .font(.system(.headline, design: .rounded))
                                Text(p.barcode)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text(p.finalPrice.arsCurrency)
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                                    .foregroundStyle(.mpBrown)
                            }
                            Spacer()
                        }
                        .padding()

                        Divider().padding(.horizontal)

                        // Cantidad
                        HStack {
                            Text("Cantidad")
                                .font(.system(.body, design: .rounded))
                            Spacer()
                            HStack(spacing: 16) {
                                Button {
                                    if qty > 1 { qty -= 1 }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(qty > 1 ? .mpOrange : .secondary)
                                }
                                .disabled(qty <= 1)

                                Text("\(qty)")
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                                    .frame(width: 32, alignment: .center)

                                Button {
                                    qty += 1
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.mpOrange)
                                }
                            }
                        }
                        .padding()

                        Divider().padding(.horizontal)

                        HStack {
                            Text("Subtotal")
                                .foregroundStyle(.secondary)
                                .font(.system(.subheadline, design: .rounded))
                            Spacer()
                            Text((p.finalPrice * Double(qty)).arsCurrency)
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(.mpBrown)
                        }
                        .padding()
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                }

                Spacer()

                Button {
                    guard let p = found else { return }
                    onAdd(p, qty)
                    dismiss()
                } label: {
                    Label("Agregar al ticket", systemImage: "plus.circle.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            found != nil
                                ? AnyShapeStyle(LinearGradient(colors: [.mpAmber, .mpOrange], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(Color.secondary.opacity(0.2))
                        )
                        .foregroundStyle(found != nil ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: found != nil ? .mpOrange.opacity(0.4) : .clear, radius: 8, y: 4)
                }
                .disabled(found == nil)
            }
            .padding()
            .background(Color.mpCream)
            .navigationTitle("Ingresar código")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
    }

    private func categoryEmoji(_ c: String) -> String {
        ["Electrónica":"📱","Ropa":"👕","Alimentos":"🍎","Herramientas":"🔧","Libros":"📚","Bebidas":"🥤"][c] ?? "📦"
    }
}

// MARK: - Ticket Sheet

struct TicketSheet: View {
    @EnvironmentObject var checkoutVM: CheckoutViewModel
    @EnvironmentObject var productVM: ProductViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if checkoutVM.items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cart")
                            .font(.system(size: 52))
                            .foregroundStyle(.secondary)
                        Text("El ticket está vacío")
                            .font(.system(.title3, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.mpCream)
                } else {
                    List {
                        ForEach(checkoutVM.items) { item in
                            TicketItemRow(item: item)
                                .environmentObject(checkoutVM)
                                .listRowBackground(Color.white)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                        .onDelete { idxs in
                            idxs.forEach { checkoutVM.remove(item: checkoutVM.items[$0]) }
                        }

                        Section {
                            HStack {
                                Text("Total")
                                    .font(.system(.headline, design: .rounded))
                                Spacer()
                                Text(checkoutVM.total.arsCurrency)
                                    .font(.system(.title3, design: .rounded).weight(.bold))
                                    .foregroundStyle(.mpBrown)
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.mpSand)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .background(Color.mpCream)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Ticket actual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Listo") { dismiss() }
                }
                if !checkoutVM.items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Vaciar", role: .destructive) {
                            checkoutVM.clear()
                            dismiss()
                        }
                        .foregroundStyle(.mpDanger)
                    }
                }
            }
        }
    }
}

struct TicketItemRow: View {
    @EnvironmentObject var checkoutVM: CheckoutViewModel
    let item: CartItem

    private func emoji(_ c: String) -> String {
        ["Electrónica":"📱","Ropa":"👕","Alimentos":"🍎","Herramientas":"🔧","Libros":"📚","Bebidas":"🥤"][c] ?? "📦"
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji(item.product.category))
                .frame(width: 38, height: 38)
                .background(Color.mpSand)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.product.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(item.product.finalPrice.arsCurrency + " c/u")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    checkoutVM.updateQty(item: item, qty: item.quantity - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.mpOrange)
                        .font(.title3)
                }

                Text("\(item.quantity)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .frame(width: 24, alignment: .center)

                Button {
                    checkoutVM.updateQty(item: item, qty: item.quantity + 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.mpOrange)
                        .font(.title3)
                }
            }

            Text(item.subtotal.arsCurrency)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.mpBrown)
                .frame(width: 68, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}
