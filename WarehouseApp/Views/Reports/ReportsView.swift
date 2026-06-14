import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var reportVM: ReportViewModel
    @EnvironmentObject var productVM: ProductViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summarySection
                lowStockSection
                historySection
            }
            .padding()
        }
        .background(Color.mpCream)
        .navigationTitle("Reportes")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Summary cards

    private var summarySection: some View {
        VStack(spacing: 12) {
            sectionHeader("VENTAS")
            HStack(spacing: 12) {
                ReportStatCard(title: "Hoy",    value: reportVM.todayTotal.arsCurrency,  sub: "\(reportVM.todayCount) venta\(reportVM.todayCount == 1 ? "" : "s")", color: .mpGreen)
                ReportStatCard(title: "Semana", value: reportVM.weekTotal.arsCurrency,   sub: "",                                                                    color: .mpAmber)
                ReportStatCard(title: "Mes",    value: reportVM.monthTotal.arsCurrency,  sub: "",                                                                    color: .mpOrange)
            }
        }
    }

    // MARK: - Low stock

    private var lowStockProducts: [Product] {
        productVM.products
            .filter { $0.stock <= ReportViewModel.lowStockThreshold }
            .sorted { $0.stock < $1.stock }
    }

    @ViewBuilder
    private var lowStockSection: some View {
        if !lowStockProducts.isEmpty {
            VStack(spacing: 12) {
                sectionHeader("STOCK BAJO")
                VStack(spacing: 0) {
                    ForEach(lowStockProducts) { product in
                        LowStockRow(product: product)
                        if product.id != lowStockProducts.last?.id {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            }
        }
    }

    // MARK: - Daily history

    @ViewBuilder
    private var historySection: some View {
        VStack(spacing: 12) {
            sectionHeader("HISTORIAL DE CIERRES")
            if reportVM.summaries.isEmpty {
                Text("Sin cierres de caja registrados")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                VStack(spacing: 0) {
                    ForEach(reportVM.summaries) { s in
                        DailySummaryRow(summary: s)
                        if s.id != reportVM.summaries.last?.id {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sub-views

private struct ReportStatCard: View {
    let title: String
    let value: String
    let sub: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.mpBrown)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            if !sub.isEmpty {
                Text(sub)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

private struct LowStockRow: View {
    let product: Product

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(product.barcode)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                Text(product.stock == 0 ? "Sin stock" : "\(product.stock) restantes")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
            }
            .foregroundStyle(product.stock == 0 ? .mpDanger : .mpAmber)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct DailySummaryRow: View {
    let summary: DailySummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.date.formatted(.dateTime.day().month(.wide).year()))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("\(summary.cantidadVentas) venta\(summary.cantidadVentas == 1 ? "" : "s") · \(summary.dominantMethod)\(summary.operadorName.map { " · \($0)" } ?? "")")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(summary.totalVentas.arsCurrency)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.mpBrown)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
