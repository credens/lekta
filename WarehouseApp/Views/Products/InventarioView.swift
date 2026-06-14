import SwiftUI

struct InventarioView: View {
    @EnvironmentObject var productVM: ProductViewModel
    @Environment(\.dismiss) private var dismiss

    enum BusquedaMode { case barcode, nombre }

    @State private var busquedaMode: BusquedaMode = .barcode
    @State private var barcodeInput = ""
    @State private var showNombreSheet = false
    @State private var productoSeleccionado: Product?
    @State private var showAlta = false
    @State private var barcodeNotFound = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                altaSection
                gestionarSection
                if let p = productoSeleccionado {
                    ProductoAccionesCard(producto: p) {
                        productoSeleccionado = nil
                        barcodeInput = ""
                    }
                    .environmentObject(productVM)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                listaResumenSection
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .animation(.spring(response: 0.3), value: productoSeleccionado?.id)
        }
        .background(Color.mpCream)
        .navigationTitle("Inventario")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(productVM.products.count) productos")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showAlta) {
            NavigationStack {
                ProductDetailView()
                    .environmentObject(productVM)
            }
        }
        .sheet(isPresented: $showNombreSheet) {
            ProductPickerSheet(productos: productVM.products.sorted { $0.name < $1.name }) { p in
                productoSeleccionado = p
                showNombreSheet = false
            }
        }
    }

    // MARK: Alta

    private var altaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Dar de alta")
            Button {
                showAlta = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Nuevo producto")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .opacity(0.5)
                }
                .padding()
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(Color.mpOrange)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            }
        }
    }

    // MARK: Gestionar (baja / modificar precio)

    private var gestionarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Modificar / Dar de baja")

            // Mode toggle
            HStack(spacing: 0) {
                modeTab(label: "Código de barras", icon: "barcode", mode: .barcode)
                modeTab(label: "Por nombre", icon: "magnifyingglass", mode: .nombre)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.05), lineWidth: 1))

            if busquedaMode == .barcode {
                barcodeSearchField
            } else {
                Button {
                    showNombreSheet = true
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text(productoSeleccionado?.name ?? "Buscar producto…")
                            .foregroundStyle(productoSeleccionado == nil ? .secondary : .primary)
                            .font(.system(.body, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                }
            }

            if barcodeNotFound {
                Label("Código no encontrado", systemImage: "exclamationmark.circle")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.mpDanger)
                    .padding(.top, -4)
            }
        }
    }

    private var barcodeSearchField: some View {
        HStack {
            Image(systemName: "barcode.viewfinder")
                .foregroundStyle(.secondary)
            TextField("Ingresá el código EAN-13", text: $barcodeInput)
                .keyboardType(.numberPad)
                .font(.system(.body, design: .monospaced))
                .onChange(of: barcodeInput) { _, code in
                    barcodeNotFound = false
                    if code.count == 13 {
                        if let found = productVM.find(barcode: code) {
                            productoSeleccionado = found
                        } else {
                            barcodeNotFound = true
                            productoSeleccionado = nil
                        }
                    } else if code.isEmpty {
                        productoSeleccionado = nil
                    }
                }
            if !barcodeInput.isEmpty {
                Button { barcodeInput = ""; productoSeleccionado = nil; barcodeNotFound = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: Lista resumen

    private var listaResumenSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Todos los productos")
            let sortedProducts = productVM.products.sorted { $0.name < $1.name }
            VStack(spacing: 0) {
                ForEach(sortedProducts) { p in
                    Button {
                        productoSeleccionado = p
                        if busquedaMode == .barcode { barcodeInput = p.barcode }
                    } label: {
                        HStack(spacing: 12) {
                            Text(categoryEmoji(p.category))
                                .frame(width: 36, height: 36)
                                .background(Color.mpSand)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(p.barcode)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(p.finalPrice.arsCurrency)
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .foregroundStyle(.mpBrown)
                                Text("\(p.stock) u.")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(p.stock < 5 ? .mpDanger : .secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .background(productoSeleccionado?.id == p.id ? Color.mpSand : Color.white)
                    if p.id != sortedProducts.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        }
    }

    // MARK: Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }

    private func modeTab(label: String, icon: String, mode: BusquedaMode) -> some View {
        Button {
            busquedaMode = mode
            productoSeleccionado = nil
            barcodeInput = ""
            barcodeNotFound = false
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(busquedaMode == mode ? Color.mpOrange : Color.clear)
            .foregroundStyle(busquedaMode == mode ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .padding(3)
        }
    }

    private func categoryEmoji(_ c: String) -> String {
        ["Electrónica":"📱","Ropa":"👕","Alimentos":"🍎","Herramientas":"🔧","Libros":"📚","Bebidas":"🥤"][c] ?? "📦"
    }
}

// MARK: - Acciones sobre producto seleccionado

struct ProductoAccionesCard: View {
    @EnvironmentObject var productVM: ProductViewModel
    @Environment(\.dismiss) private var dismiss

    let producto: Product
    let onDismiss: () -> Void

    @State private var precioEditado: String = ""
    @State private var showDeleteConfirm = false
    @State private var showFullEdit = false
    @State private var precioCambiado = false

    init(producto: Product, onDismiss: @escaping () -> Void) {
        self.producto = producto
        self.onDismiss = onDismiss
        _precioEditado = State(initialValue: String(format: "%.0f", producto.price))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header producto
            HStack(spacing: 12) {
                Text(categoryEmoji(producto.category))
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(Color.mpSand)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(producto.name)
                        .font(.system(.headline, design: .rounded))
                    Text(producto.barcode)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
            .padding()

            Divider()

            // Editar precio
            VStack(alignment: .leading, spacing: 8) {
                Text("PRECIO")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                HStack(spacing: 10) {
                    HStack {
                        Text("$")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.mpBrown)
                        TextField("0", text: $precioEditado)
                            .keyboardType(.numberPad)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.mpBrown)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.mpSand)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        guardarPrecio()
                    } label: {
                        Text(precioCambiado ? "✓ Guardado" : "Guardar")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(precioCambiado ? Color.mpGreen : Color.mpOrange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(Double(precioEditado) == producto.price)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 14)

            Divider()

            // Editar completo / Dar de baja
            HStack(spacing: 10) {
                Button {
                    showFullEdit = true
                } label: {
                    Label("Editar todo", systemImage: "pencil")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .foregroundStyle(.mpBrown)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.mpSand, lineWidth: 1))
                }

                Button {
                    showDeleteConfirm = true
                } label: {
                    Label("Dar de baja", systemImage: "trash")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.mpDanger.opacity(0.12))
                        .foregroundStyle(.mpDanger)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .mpOrange.opacity(0.15), radius: 12, y: 4)
        .confirmationDialog("Dar de baja \"\(producto.name)\"", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                productVM.delete(producto)
                onDismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
        .sheet(isPresented: $showFullEdit) {
            NavigationStack {
                ProductDetailView(product: producto)
                    .environmentObject(productVM)
            }
        }
    }

    private func guardarPrecio() {
        guard var p = productVM.products.first(where: { $0.id == producto.id }),
              let nuevo = Double(precioEditado) else { return }
        p.price = nuevo
        productVM.upsert(p)
        withAnimation { precioCambiado = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { precioCambiado = false }
        }
    }

    private func categoryEmoji(_ c: String) -> String {
        ["Electrónica":"📱","Ropa":"👕","Alimentos":"🍎","Herramientas":"🔧","Libros":"📚","Bebidas":"🥤"][c] ?? "📦"
    }
}

// MARK: - Picker por nombre (sheet)

struct ProductPickerSheet: View {
    let productos: [Product]
    let onSelect: (Product) -> Void

    @State private var search = ""
    @Environment(\.dismiss) private var dismiss

    var filtered: [Product] {
        search.isEmpty ? productos : productos.filter {
            $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { p in
                Button {
                    onSelect(p)
                } label: {
                    HStack(spacing: 12) {
                        Text(emoji(p.category))
                            .frame(width: 36, height: 36)
                            .background(Color.mpSand)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(p.finalPrice.arsCurrency)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(p.stock) u.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(p.stock < 5 ? .mpDanger : .secondary)
                    }
                }
                .listRowBackground(Color.white)
            }
            .listStyle(.plain)
            .background(Color.mpCream)
            .searchable(text: $search, prompt: "Buscar producto")
            .navigationTitle("Seleccioná un producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func emoji(_ c: String) -> String {
        ["Electrónica":"📱","Ropa":"👕","Alimentos":"🍎","Herramientas":"🔧","Libros":"📚","Bebidas":"🥤"][c] ?? "📦"
    }
}
