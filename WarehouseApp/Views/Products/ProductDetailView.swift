import SwiftUI

struct ProductDetailView: View {
    @EnvironmentObject var productVM: ProductViewModel
    @Environment(\.dismiss) private var dismiss

    // State
    @State private var name: String = ""
    @State private var price: String = ""
    @State private var stock: String = ""
    @State private var discount: Double = 0
    @State private var category: String = ""
    @State private var barcode: String = ""
    @State private var variants: [Product.Variant] = []

    private let isNew: Bool
    private let originalProduct: Product?

    // New product with optional pre-loaded barcode
    init(barcode: String? = nil) {
        isNew = true
        originalProduct = nil
        _barcode = State(initialValue: barcode ?? "")
    }

    // Edit existing
    init(product: Product) {
        isNew = false
        originalProduct = product
        _name = State(initialValue: product.name)
        _price = State(initialValue: String(product.price))
        _stock = State(initialValue: String(product.stock))
        _discount = State(initialValue: product.discount * 100)
        _category = State(initialValue: product.category)
        _barcode = State(initialValue: product.barcode)
        _variants = State(initialValue: product.variants)
    }

    var body: some View {
        Form {
            Section("Información básica") {
                LabeledContent("Código") {
                    TextField("EAN-13", text: $barcode)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Nombre") {
                    TextField("Nombre del producto", text: $name)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Precio") {
                    TextField("0.00", text: $price)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Stock inicial") {
                    TextField("0", text: $stock)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Categoría") {
                    TextField("Ej: Electrónica", text: $category)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Descuento")
                        Spacer()
                        Text("\(Int(discount))%")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.mpOrange)
                    }
                    Slider(value: $discount, in: 0...50, step: 1)
                        .tint(.mpOrange)
                }
            } header: {
                Text("Descuento")
            }

            Section {
                ForEach($variants) { $variant in
                    VariantRow(variant: $variant)
                }
                .onDelete { variants.remove(atOffsets: $0) }

                Button {
                    variants.append(Product.Variant(name: "", value: "", priceDelta: 0, stock: 0))
                } label: {
                    Label("Agregar variante", systemImage: "plus.circle")
                        .foregroundStyle(.mpOrange)
                }
            } header: {
                Text("Variantes")
            }

            if !isNew {
                Section {
                    Button(role: .destructive) {
                        if let p = originalProduct { productVM.delete(p) }
                        dismiss()
                    } label: {
                        Label("Eliminar producto", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isNew ? "Nuevo producto" : "Editar producto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Guardar") { save() }
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.mpOrange)
                    .disabled(name.isEmpty || barcode.isEmpty)
            }
            if isNew {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let sanitizedPrice = BarcodeService.sanitizedPrice(price)
        let sanitizedStock = BarcodeService.sanitizedStock(stock)
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespaces)
        let trimmedName    = name.trimmingCharacters(in: .whitespaces)
        let trimmedCat     = category.trimmingCharacters(in: .whitespaces)

        var product = originalProduct ?? Product(
            barcode: trimmedBarcode,
            name: trimmedName,
            price: sanitizedPrice,
            stock: sanitizedStock,
            variants: variants,
            discount: discount / 100,
            category: trimmedCat
        )
        product.name     = trimmedName
        product.price    = sanitizedPrice
        product.stock    = sanitizedStock
        product.discount = discount / 100
        product.category = trimmedCat
        product.barcode  = trimmedBarcode
        product.variants = variants

        productVM.upsert(product)
        dismiss()
    }
}

// MARK: - Variant Row

struct VariantRow: View {
    @Binding var variant: Product.Variant

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Nombre (ej: Color)", text: $variant.name)
                TextField("Valor (ej: Rojo)", text: $variant.value)
            }
            HStack {
                TextField("Delta precio", value: $variant.priceDelta, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Stock", value: $variant.stock, format: .number)
                    .keyboardType(.numberPad)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .font(.system(.subheadline, design: .rounded))
    }
}
