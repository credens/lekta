import SwiftUI

struct HomeView: View {
    @EnvironmentObject var cajaVM: CajaViewModel
    @EnvironmentObject var productVM: ProductViewModel
    @EnvironmentObject var checkoutVM: CheckoutViewModel
    @EnvironmentObject var authService: MPAuthService
    @EnvironmentObject var reportVM: ReportViewModel
    @EnvironmentObject var operadorVM: OperadorViewModel

    @State private var navigate: HomeDestino?
    @State private var showCerrarCajaConfirm = false
    @State private var showResumen = false
    @State private var showOperadorLogin = false
    @State private var masterAction: MasterAction?

    private var lowStockCount: Int {
        productVM.products.filter { $0.stock <= ReportViewModel.lowStockThreshold }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.mpCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView
                    Spacer()
                    actionButtons
                    Spacer()
                    footerInfo
                }
            }
            .navigationDestination(item: $navigate) { destino in
                switch destino {
                case .cobrar:
                    CobrarView()
                        .environmentObject(productVM)
                        .environmentObject(checkoutVM)
                        .environmentObject(cajaVM)
                case .inventario:
                    InventarioView()
                        .environmentObject(productVM)
                case .reportes:
                    ReportsView()
                        .environmentObject(reportVM)
                        .environmentObject(productVM)
                case .operadores:
                    OperadoresView()
                        .environmentObject(operadorVM)
                }
            }
            .alert("Cerrar Caja", isPresented: $showCerrarCajaConfirm) {
                Button("Cancelar", role: .cancel) {}
                Button("Cerrar", role: .destructive) {
                    Task {
                        await cajaVM.cerrarCaja()
                        if let resumen = cajaVM.ultimoResumen {
                            reportVM.add(from: resumen)
                            showResumen = true
                        }
                    }
                }
            } message: {
                Text("Se cerrará la caja y se conciliará con MercadoPago. ¿Confirmás?")
            }
            .sheet(isPresented: $showResumen) {
                if let resumen = cajaVM.ultimoResumen {
                    ResumenCajaView(resumen: resumen)
                }
            }
            .sheet(isPresented: $showOperadorLogin) {
                OperadorLoginSheet { operador in
                    Task { await cajaVM.abrirCaja(operador: operador) }
                }
                .environmentObject(operadorVM)
            }
            .sheet(item: $masterAction) { action in
                MasterPINSheet(actionTitle: action.title) {
                    switch action {
                    case .gestionOperadores: navigate = .operadores
                    case .desconectarMP:     authService.desconectar()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            masterAction = .gestionOperadores
                        } label: {
                            Label("Gestión de operadores", systemImage: "person.2")
                        }
                        Divider()
                        Button(role: .destructive) {
                            masterAction = .desconectarMP
                        } label: {
                            Label("Desconectar MercadoPago", systemImage: "minus.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.mpBrown)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 6) {
            Text("🏪 Mi Negocio")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.mpBrown)

            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)

            cajaBadge
        }
        .padding(.top, 60)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var cajaBadge: some View {
        switch cajaVM.estado {
        case .cerrada:
            Label("Caja cerrada", systemImage: "lock.fill")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.secondary)
                .clipShape(Capsule())

        case .abriendo:
            Label("Abriendo caja...", systemImage: "clock")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.mpAmber)
                .clipShape(Capsule())

        case .abierta(let desde):
            VStack(spacing: 3) {
                Label("Caja abierta · \(desde.formatted(.dateTime.hour().minute()))", systemImage: "checkmark.circle.fill")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                if let op = cajaVM.currentOperadorName {
                    Text(op)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.mpGreen)
            .clipShape(Capsule())

        case .cerrando:
            Label("Cerrando caja...", systemImage: "clock")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.mpOrange)
                .clipShape(Capsule())
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 16) {
            HomeActionButton(
                icon: "💰",
                title: "Abrir Caja",
                subtitle: "Habilita cobros y conecta con MP",
                style: .green,
                isLoading: { if case .abriendo = cajaVM.estado { return true }; return false }(),
                isDisabled: cajaVM.estaAbierta || { if case .abriendo = cajaVM.estado { return true }; return false }() || { if case .cerrando = cajaVM.estado { return true }; return false }()
            ) {
                showOperadorLogin = true
            }

            HomeActionButton(
                icon: "📷",
                title: "Cobrar",
                subtitle: "Escanear y procesar ventas",
                style: .primary,
                isLoading: false,
                isDisabled: !cajaVM.estaAbierta
            ) {
                navigate = .cobrar
            }

            HomeActionButton(
                icon: "🔒",
                title: "Cerrar Caja",
                subtitle: "Cierra sesión y concilia MP",
                style: .danger,
                isLoading: { if case .cerrando = cajaVM.estado { return true }; return false }(),
                isDisabled: !cajaVM.estaAbierta
            ) {
                showCerrarCajaConfirm = true
            }

            HomeActionButton(
                icon: "📦",
                title: "Inventario",
                subtitle: lowStockCount > 0 ? "\(lowStockCount) producto\(lowStockCount == 1 ? "" : "s") con stock bajo ⚠️" : "Productos, stock y precios",
                style: .neutral,
                isLoading: false,
                isDisabled: false
            ) {
                navigate = .inventario
            }

            HomeActionButton(
                icon: "📊",
                title: "Reportes",
                subtitle: "Ventas, historial y stock",
                style: .neutral,
                isLoading: false,
                isDisabled: false
            ) {
                navigate = .reportes
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Footer con stats de la sesión

    @ViewBuilder
    private var footerInfo: some View {
        if cajaVM.estaAbierta {
            VStack(spacing: 12) {
                Divider().padding(.horizontal)
                HStack(spacing: 0) {
                    statCell(label: "Ventas", value: "\(cajaVM.cantidadVentas)")
                    Divider().frame(height: 32)
                    statCell(label: "Total", value: cajaVM.totalVentas.arsCurrency)
                    Divider().frame(height: 32)
                    statCell(label: "MP", value: cajaVM.totalMP.arsCurrency)
                    Divider().frame(height: 32)
                    statCell(label: "Efectivo", value: cajaVM.totalEfectivo.arsCurrency)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 40)
        } else {
            Spacer().frame(height: 40)
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.mpBrown)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Navigation destination

enum HomeDestino: Hashable, Identifiable {
    case cobrar
    case inventario
    case reportes
    case operadores
    var id: Self { self }
}

// MARK: - Master action

enum MasterAction: Identifiable {
    case gestionOperadores
    case desconectarMP

    var id: Int {
        switch self {
        case .gestionOperadores: return 0
        case .desconectarMP:     return 1
        }
    }

    var title: String {
        switch self {
        case .gestionOperadores: return "Gestión de operadores"
        case .desconectarMP:     return "Desconectar MercadoPago"
        }
    }
}

// MARK: - HomeActionButton

struct HomeActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let style: ButtonStyle
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    enum ButtonStyle { case primary, green, danger, neutral }

    private var bg: AnyShapeStyle {
        switch style {
        case .primary: return AnyShapeStyle(LinearGradient(colors: [.mpAmber, .mpOrange], startPoint: .leading, endPoint: .trailing))
        case .green:   return AnyShapeStyle(Color.mpGreen)
        case .danger:  return AnyShapeStyle(Color.mpDanger)
        case .neutral: return AnyShapeStyle(Color.white)
        }
    }

    private var fgColor: Color { style == .neutral ? .primary : .white }

    private var shadowColor: Color {
        switch style {
        case .primary: return .mpOrange.opacity(0.4)
        case .green:   return .mpGreen.opacity(0.35)
        case .danger:  return .mpDanger.opacity(0.3)
        case .neutral: return .black.opacity(0.08)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(icon)
                    .font(.system(size: 32))
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .opacity(0.8)
                }

                Spacer()

                if isLoading {
                    ProgressView().tint(fgColor)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .opacity(0.7)
                }
            }
            .foregroundStyle(AnyShapeStyle(fgColor))
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(isDisabled ? 0.38 : 1)
            .shadow(color: isDisabled ? .clear : shadowColor, radius: 10, y: 5)
        }
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - ResumenCajaView

struct ResumenCajaView: View {
    let resumen: ResumenCaja
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.mpGreen)
                    Text("Caja cerrada")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                    Text("\(resumen.apertura.formatted(.dateTime.hour().minute())) – \(resumen.cierre.formatted(.dateTime.hour().minute()))")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    if let op = resumen.operadorName {
                        Text("Operador: \(op)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 0) {
                    resumenRow(label: "Ventas totales", value: "\(resumen.cantidadVentas)", isTotal: false)
                    resumenRow(label: "Total recaudado", value: resumen.totalVentas.arsCurrency, isTotal: true)
                    resumenRow(label: "Por MercadoPago", value: resumen.totalMP.arsCurrency, isTotal: false)
                    resumenRow(label: "En efectivo", value: resumen.totalEfectivo.arsCurrency, isTotal: false)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Button("Listo") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient(colors: [.mpAmber, .mpOrange], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .font(.system(.headline, design: .rounded))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)
            .background(Color.mpCream)
            .navigationTitle("Resumen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func resumenRow(label: String, value: String, isTotal: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(isTotal ? .headline : .subheadline, design: .rounded))
                .foregroundStyle(isTotal ? Color.primary : Color.secondary)
            Spacer()
            Text(value)
                .font(.system(isTotal ? .headline : .subheadline, design: .rounded).weight(isTotal ? .bold : .regular))
                .foregroundStyle(isTotal ? Color.mpBrown : Color.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider().padding(.horizontal)
        }
    }
}
