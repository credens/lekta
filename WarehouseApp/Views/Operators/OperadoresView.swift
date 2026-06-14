import SwiftUI

struct OperadoresView: View {
    @EnvironmentObject var operadorVM: OperadorViewModel
    @State private var showAdd = false

    var body: some View {
        List {
            let active   = operadorVM.operadores.filter { $0.isActive }
            let inactive = operadorVM.operadores.filter { !$0.isActive }

            Section("Activos") {
                if active.isEmpty {
                    Text("Sin operadores activos")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(active) { op in
                        OperadorRow(op: op, onDeactivate: { operadorVM.deactivate(op) })
                    }
                }
            }

            if !inactive.isEmpty {
                Section("Inactivos") {
                    ForEach(inactive) { op in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(op.name)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text("Dado de baja")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Reactivar") { operadorVM.reactivate(op) }
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(.mpGreen)
                        }
                    }
                }
            }
        }
        .background(Color.mpCream)
        .scrollContentBackground(.hidden)
        .navigationTitle("Operadores")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus").foregroundStyle(.mpBrown)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddOperadorSheet().environmentObject(operadorVM)
        }
    }
}

// MARK: - Operator row

private struct OperadorRow: View {
    let op: Operador
    let onDeactivate: () -> Void
    @State private var showConfirm = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(op.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("Desde \(op.createdAt.formatted(.dateTime.day().month().year()))")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { showConfirm = true } label: {
                Image(systemName: "person.badge.minus")
                    .foregroundStyle(.mpDanger)
            }
        }
        .alert("Dar de baja a \(op.name)", isPresented: $showConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Dar de baja", role: .destructive) { onDeactivate() }
        } message: {
            Text("Ya no podrá iniciar turno. Podés reactivarlo más tarde.")
        }
    }
}

// MARK: - Add operator sheet

private struct AddOperadorSheet: View {
    @EnvironmentObject var operadorVM: OperadorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var pin = ""
    @State private var pinConfirm = ""
    @FocusState private var focused: Bool

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && pin.count == 4 && pin == pinConfirm
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos del operador") {
                    TextField("Nombre", text: $name)
                        .focused($focused)
                }
                Section("PIN (4 dígitos)") {
                    SecureField("PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .onChange(of: pin) { _, v in pin = String(v.filter(\.isNumber).prefix(4)) }
                    SecureField("Confirmar PIN", text: $pinConfirm)
                        .keyboardType(.numberPad)
                        .onChange(of: pinConfirm) { _, v in pinConfirm = String(v.filter(\.isNumber).prefix(4)) }
                }
                if pin.count == 4 && !pinConfirm.isEmpty && pin != pinConfirm {
                    Section {
                        Label("Los PINs no coinciden", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.mpDanger)
                            .font(.system(.caption, design: .rounded))
                    }
                }
            }
            .navigationTitle("Nuevo operador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        operadorVM.add(name: name, pin: pin)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .font(.system(.headline, design: .rounded))
                }
            }
            .onAppear { focused = true }
        }
    }
}
