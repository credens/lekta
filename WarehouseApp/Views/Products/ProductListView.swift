import SwiftUI

struct ProductListView: View {
    @EnvironmentObject var productVM: ProductViewModel
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showCreate = false

    var filtered: [Product] {
        var list = productVM.products
        if let cat = selectedCategory {
            list = list.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.barcode.contains(searchText)
            }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category chips
                if !productVM.categories.isEmpty {
                    categoryChips
                }

                List {
                    ForEach(filtered) { product in
                        NavigationLink(destination: ProductDetailView(product: product).environmentObject(productVM)) {
                            ProductRow(product: product)
                        }
                        .listRowBackground(Color.white)
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { i in productVM.delete(filtered[i]) }
                    }
                }
                .listStyle(.plain)
                .background(Color.mpCream)

                // Footer
                footerCard
            }
            .background(Color.mpCream)
            .navigationTitle("Productos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.mpOrange)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar por nombre o código")
            .sheet(isPresented: $showCreate) {
                NavigationStack {
                    ProductDetailView()
                        .environmentObject(productVM)
                }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "Todo", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(productVM.categories, id: \.self) { cat in
                    chip(label: cat, isSelected: selectedCategory == cat) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color.mpCream)
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.mpOrange : Color.white)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
    }

    private var footerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Valor total de stock")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(productVM.totalStockValue.arsCurrency)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.mpBrown)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Productos")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("\(productVM.products.count)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
            }
        }
        .padding()
        .background(Color.white)
        .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
    }
}

// MARK: - Product Row

struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            Text(categoryEmoji(product.category))
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color.mpSand)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(product.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    if product.discount > 0 {
                        Text("-\(Int(product.discount * 100))%")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.mpYellow)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                }
                Text(product.barcode)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(product.finalPrice.arsCurrency)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.mpBrown)
                Text("\(product.stock) u.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(product.stock < 5 ? .mpDanger : .secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func categoryEmoji(_ category: String) -> String {
        let map: [String: String] = [
            "Electrónica": "📱", "Ropa": "👕", "Alimentos": "🍎",
            "Herramientas": "🔧", "Libros": "📚", "Bebidas": "🥤"
        ]
        return map[category] ?? "📦"
    }
}
