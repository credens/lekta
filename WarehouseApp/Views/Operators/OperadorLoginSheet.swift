import SwiftUI

struct OperadorLoginSheet: View {
    @EnvironmentObject var operadorVM: OperadorViewModel
    @Environment(\.dismiss) private var dismiss

    let onSuccess: (Operador) -> Void

    @State private var selectedID: UUID?
    @State private var pin = ""
    @State private var shakeOffset: CGFloat = 0

    private var activeOps: [Operador] { operadorVM.activeOperadores }

    var body: some View {
        NavigationStack {
            Group {
                if activeOps.isEmpty {
                    emptyState
                } else {
                    loginContent
                }
            }
            .background(Color.mpCream.ignoresSafeArea())
            .navigationTitle("Iniciar turno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(.mpBrown)
                }
            }
        }
        .onAppear {
            selectedID = activeOps.first?.id
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.mpAmber)
            Text("No hay operadores")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.mpBrown)
            Text("El maestro debe agregar operadores desde\nConfiguración › Gestión de operadores")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Login content

    private var loginContent: some View {
        VStack(spacing: 32) {
            // Operator picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(activeOps) { op in
                        Button {
                            selectedID = op.id
                            pin = ""
                        } label: {
                            Text(op.name)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 11)
                                .background(
                                    selectedID == op.id
                                        ? AnyShapeStyle(LinearGradient(colors: [.mpAmber, .mpOrange], startPoint: .leading, endPoint: .trailing))
                                        : AnyShapeStyle(Color.white)
                                )
                                .foregroundStyle(selectedID == op.id ? .white : Color.mpBrown)
                                .clipShape(Capsule())
                                .shadow(color: selectedID == op.id ? .mpOrange.opacity(0.35) : .black.opacity(0.07), radius: 6, y: 3)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            // PIN dots
            HStack(spacing: 18) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < pin.count ? Color.mpBrown : Color.mpSand)
                        .frame(width: 16, height: 16)
                }
            }
            .offset(x: shakeOffset)

            // Numpad
            numpad

            Spacer()
        }
        .padding(.top, 28)
    }

    private var numpad: some View {
        VStack(spacing: 14) {
            ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { digit in
                        PINKey(label: "\(digit)") { appendDigit("\(digit)") }
                    }
                }
            }
            HStack(spacing: 24) {
                Color.clear.frame(width: 72, height: 72)
                PINKey(label: "0") { appendDigit("0") }
                PINKey(label: "⌫", isDestructive: true) { deleteDigit() }
            }
        }
    }

    // MARK: - Logic

    private func appendDigit(_ d: String) {
        guard pin.count < 4 else { return }
        pin += d
        if pin.count == 4 { authenticate() }
    }

    private func deleteDigit() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
    }

    private func authenticate() {
        guard let id = selectedID,
              let operador = operadorVM.login(id: id, pin: pin) else {
            pin = ""
            triggerShake()
            return
        }
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            onSuccess(operador)
        }
    }

    private func triggerShake() {
        withAnimation(.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shakeOffset = 0 }
    }
}

// MARK: - PIN Key

private struct PINKey: View {
    let label: String
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.title2, design: .rounded).weight(.medium))
                .foregroundStyle(isDestructive ? Color.mpDanger : Color.mpBrown)
                .frame(width: 72, height: 72)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
        }
    }
}
