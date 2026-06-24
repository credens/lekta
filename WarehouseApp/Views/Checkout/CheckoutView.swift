import SwiftUI
import CoreImage.CIFilterBuiltins

struct CheckoutView: View {
    @EnvironmentObject var checkoutVM: CheckoutViewModel
    @EnvironmentObject var productVM: ProductViewModel
    @EnvironmentObject var cajaVM: CajaViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var paymentMethod: PaymentMethod = .qrMP
    @State private var orderID: String?
    @State private var preferenceID: String?
    @State private var qrImage: UIImage?
    @State private var orderStatus: BackendOrderStatus = .pending
    @State private var isGeneratingQR = false
    @State private var qrError: String?
    @State private var pollingTask: Task<Void, Never>?
    @State private var showSuccess = false
    @State private var confirmedTotal: Double = 0

    // Efectivo
    @State private var montoRecibido: String = ""
    @FocusState private var cashFocused: Bool

    var vuelto: Double {
        max(0, (Double(montoRecibido) ?? 0) - checkoutVM.total)
    }
    var montoSuficiente: Bool {
        (Double(montoRecibido) ?? 0) >= checkoutVM.total
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerView

                if checkoutVM.items.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 20) {
                        itemsSection
                        totalsSection
                        paymentMethodSection
                        paymentActionSection

                        confirmButton
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .background(Color.mpCream)
        .navigationTitle("Cobrar")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showSuccess { successOverlay }
        }
        .onChange(of: paymentMethod) { _, method in
            cancelPolling()
            qrImage = nil
            orderID = nil
            preferenceID = nil
            orderStatus = .pending
            qrError = nil
            montoRecibido = ""
            if method == .qrMP { Task { await generateQR() } }
        }
        .onAppear {
            if paymentMethod == .qrMP { Task { await generateQR() } }
        }
        .onDisappear { cancelPolling() }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 4) {
            Text("TOTAL A COBRAR")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .tracking(1.5)
            Text(checkoutVM.total.arsCurrency)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("\(checkoutVM.itemCount) artículo\(checkoutVM.itemCount == 1 ? "" : "s")")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 28)
        .background(
            LinearGradient(colors: [.mpAmber, .mpOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Ticket vacío")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Items

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ARTÍCULOS")
            VStack(spacing: 0) {
                ForEach(checkoutVM.items) { item in
                    CartItemRow(item: item)
                        .environmentObject(checkoutVM)
                        .padding(.horizontal)
                        .padding(.vertical, 11)
                    if item.id != checkoutVM.items.last?.id {
                        Divider().padding(.horizontal)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    // MARK: - Totals

    private var totalsSection: some View {
        VStack(spacing: 8) {
            if checkoutVM.discount > 0 {
                HStack {
                    Text("Subtotal").foregroundStyle(.secondary)
                    Spacer()
                    Text(checkoutVM.subtotalBeforeDiscount.arsCurrency)
                }
                HStack {
                    Text("Descuentos").foregroundStyle(.mpGreen)
                    Spacer()
                    Text("−\(checkoutVM.discount.arsCurrency)").foregroundStyle(.mpGreen)
                }
                Divider()
            }
            HStack {
                Text("Total").font(.system(.headline, design: .rounded))
                Spacer()
                Text(checkoutVM.total.arsCurrency)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.mpBrown)
            }
        }
        .font(.system(.subheadline, design: .rounded))
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Payment method selector

    private var paymentMethodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("MÉTODO DE PAGO")
            HStack(spacing: 10) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    Button {
                        withAnimation(.spring(response: 0.25)) { paymentMethod = method }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: method.icon).font(.title3)
                            Text(method.rawValue).font(.system(.caption, design: .rounded).weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(paymentMethod == method
                            ? AnyShapeStyle(LinearGradient(colors: [.mpAmber, .mpOrange], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.white)
                        )
                        .foregroundStyle(paymentMethod == method ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: paymentMethod == method ? .mpOrange.opacity(0.3) : .black.opacity(0.06), radius: 6, y: 3)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Payment action area

    @ViewBuilder
    private var paymentActionSection: some View {
        switch paymentMethod {
        case .qrMP:    qrSection
        case .pointMP: pointMPSection
        case .cash:    cashSection
        }
    }

    // QR MP
    private var qrSection: some View {
        VStack(spacing: 16) {
            if isGeneratingQR {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Generando QR...")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 120)
            } else if let err = qrError {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundStyle(.mpDanger)
                    Text(err)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        qrError = nil
                        Task { await generateQR() }
                    } label: {
                        Label("Reintentar", systemImage: "arrow.clockwise")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.mpOrange)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if let qrImage {
                VStack(spacing: 12) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

                    Text("Mostrá este código al cliente")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text(statusMessage)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // Point MP
    private var pointMPSection: some View {
        HStack(spacing: 14) {
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.mpOrange.opacity(0.6))
            VStack(alignment: .leading, spacing: 3) {
                Text("Point MP")
                    .font(.system(.headline, design: .rounded))
                Text("Próximamente disponible")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // Efectivo + calculadora de vuelto
    private var cashSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "banknote.fill")
                    .font(.title2)
                    .foregroundStyle(.mpGreen)
                Text("Pago en efectivo")
                    .font(.system(.headline, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider().padding(.horizontal)

            VStack(spacing: 14) {
                // Monto recibido
                VStack(alignment: .leading, spacing: 6) {
                    Text("MONTO RECIBIDO")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    HStack {
                        Text("$")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(.mpBrown)
                        TextField("0", text: $montoRecibido)
                            .keyboardType(.numberPad)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(.mpBrown)
                            .focused($cashFocused)
                            .onChange(of: montoRecibido) { _, v in
                                var clean = v.filter(\.isNumber)
                                if clean.count > 9 { clean = String(clean.prefix(9)) }
                                if clean != v { montoRecibido = clean }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.mpSand)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Billeteras rápidas
                let sugeridos = quickAmounts(for: checkoutVM.total)
                HStack(spacing: 8) {
                    ForEach(sugeridos, id: \.self) { amount in
                        Button {
                            montoRecibido = String(Int(amount))
                            cashFocused = false
                        } label: {
                            Text(amount.arsCurrency)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.mpSand)
                                .foregroundStyle(.mpBrown)
                                .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Vuelto
                if let recibido = Double(montoRecibido), recibido > 0 {
                    HStack {
                        Text("Vuelto")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(vuelto.arsCurrency)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(montoSuficiente ? .mpGreen : .mpDanger)
                    }
                    .padding(.horizontal, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.25), value: montoRecibido)
            .padding()
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Confirm button

    @ViewBuilder
    private var confirmButton: some View {
        let canConfirm: Bool = {
            switch paymentMethod {
            case .qrMP:    return false   // se confirma automático por polling
            case .pointMP: return false
            case .cash:    return montoSuficiente
            }
        }()

        if paymentMethod == .cash {
            Button {
                Task { await confirmPayment() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Confirmar cobro")
                        .font(.system(.headline, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    canConfirm
                        ? AnyShapeStyle(LinearGradient(colors: [.mpAmber, .mpOrange], startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color.secondary.opacity(0.2))
                )
                .foregroundStyle(canConfirm ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: canConfirm ? .mpOrange.opacity(0.45) : .clear, radius: 10, y: 5)
            }
            .disabled(!canConfirm)
        }
    }

    // MARK: - Success overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.mpGreen)
                Text("¡Cobro registrado!")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Text(confirmedTotal.arsCurrency)
                    .font(.system(.title2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                if paymentMethod == .cash, Double(montoRecibido) != nil, vuelto > 0 {
                    Text("Vuelto: \(vuelto.arsCurrency)")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.mpYellow)
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Logic

    private func generateQR() async {
        guard !checkoutVM.items.isEmpty else { return }
        isGeneratingQR = true
        qrError = nil
        defer { isGeneratingQR = false }
        do {
            let order = try await BackendCheckoutService.createOrder(
                items: checkoutVM.items,
                operatorID: cajaVM.currentOperadorName,
                cashSessionID: cajaVM.horaApertura?.ISO8601Format()
            )
            orderID = order.orderID

            let preference = try await BackendCheckoutService.createPreference(orderID: order.orderID)
            preferenceID = preference.preferenceID

            guard let qrURLString = preference.qrURLString else {
                throw BackendServiceError.missingQRURL
            }

            qrImage = makeQRImage(from: qrURLString)
            orderStatus = order.status
            startPolling(orderID: order.orderID)
        } catch {
            qrError = "No se pudo generar el QR.\nVerificá tu conexión."
        }
    }

    private func startPolling(orderID: String) {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { break }
                if let response = try? await BackendCheckoutService.fetchOrderStatus(orderID: orderID) {
                    await MainActor.run {
                        orderStatus = response.status
                    }

                    switch response.status {
                    case .approved:
                        await confirmPayment()
                        return
                    case .pending:
                        continue
                    case .rejected, .cancelled, .expired:
                        await MainActor.run {
                            qrError = failureMessage(for: response.status)
                            qrImage = nil
                        }
                        cancelPolling()
                        return
                    }
                }
            }
        }
    }

    private func cancelPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    @MainActor
    private func confirmPayment() async {
        cancelPolling()
        confirmedTotal = checkoutVM.total
        for item in checkoutVM.items {
            productVM.removeStock(barcode: item.product.barcode, qty: item.quantity)
        }
        cajaVM.registrarVenta(total: confirmedTotal, metodo: paymentMethod)

        withAnimation(.spring(response: 0.3)) { showSuccess = true }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        withAnimation { showSuccess = false }
        try? await Task.sleep(nanoseconds: 300_000_000)

        checkoutVM.clear()
        dismiss()
    }

    private func makeQRImage(from string: String) -> UIImage? {
        let ctx = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func quickAmounts(for total: Double) -> [Double] {
        let rounded = ceil(total / 100) * 100
        return [rounded, rounded + 500, rounded + 1000].filter { $0 >= total }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(1.2)
            .padding(.horizontal)
    }

    private var statusMessage: String {
        switch orderStatus {
        case .pending:
            return "Esperando confirmación de pago..."
        case .approved:
            return "Pago aprobado. Cerrando operación..."
        case .rejected:
            return "Pago rechazado"
        case .cancelled:
            return "Pago cancelado"
        case .expired:
            return "QR vencido"
        }
    }

    private func failureMessage(for status: BackendOrderStatus) -> String {
        switch status {
        case .rejected:
            return "El pago fue rechazado.\nPedile al cliente que lo reintente."
        case .cancelled:
            return "El pago fue cancelado."
        case .expired:
            return "El QR venció.\nGenerá uno nuevo para continuar."
        case .pending, .approved:
            return "No se pudo confirmar el pago."
        }
    }
}

// MARK: - Cart Item Row

struct CartItemRow: View {
    @EnvironmentObject var checkoutVM: CheckoutViewModel
    let item: CartItem

    var body: some View {
        HStack(spacing: 12) {
            Text(emoji(item.product.category))
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(Color.mpSand)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.product.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                if !item.product.variants.isEmpty {
                    Text(item.product.variants.map { "\($0.name): \($0.value)" }.joined(separator: ", "))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button { checkoutVM.updateQty(item: item, qty: item.quantity - 1) } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.mpOrange)
                }
                Text("\(item.quantity)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .frame(width: 24)
                Button { checkoutVM.updateQty(item: item, qty: item.quantity + 1) } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.mpOrange)
                }
            }
            .font(.title3)

            Text(item.subtotal.arsCurrency)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .frame(width: 72, alignment: .trailing)
                .foregroundStyle(.mpBrown)
        }
    }

    private func emoji(_ c: String) -> String {
        ["Electrónica":"📱","Ropa":"👕","Alimentos":"🍎","Herramientas":"🔧","Libros":"📚","Bebidas":"🥤"][c] ?? "📦"
    }
}
