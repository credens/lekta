import SwiftUI

struct MasterPINSheet: View {
    @Environment(\.dismiss) private var dismiss

    let actionTitle: String
    let onSuccess: () -> Void

    @State private var pin = ""
    @State private var firstPIN = ""
    @State private var isConfirming = false
    @State private var shakeOffset: CGFloat = 0

    private var isCreating: Bool { !MasterPINService.isSet }

    private var headline: String {
        if isCreating {
            return isConfirming ? "Confirmá el PIN maestro" : "Crear PIN maestro"
        }
        return actionTitle
    }

    private var caption: String {
        if isCreating {
            return isConfirming
                ? "Repetí el PIN para confirmar"
                : "Este PIN protege acciones sensibles del negocio.\nGuardalo en un lugar seguro."
        }
        return "Ingresá el PIN maestro para continuar"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Image(systemName: isCreating ? "lock.shield.fill" : "lock.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(isCreating ? .mpAmber : .mpBrown)
                    Text(headline)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.mpBrown)
                    Text(caption)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 8)

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
                VStack(spacing: 14) {
                    ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                        HStack(spacing: 24) {
                            ForEach(row, id: \.self) { digit in
                                MasterPINKey(label: "\(digit)") { appendDigit("\(digit)") }
                            }
                        }
                    }
                    HStack(spacing: 24) {
                        Color.clear.frame(width: 72, height: 72)
                        MasterPINKey(label: "0") { appendDigit("0") }
                        MasterPINKey(label: "⌫", isDestructive: true) { deleteDigit() }
                    }
                }

                Spacer()
            }
            .padding(.top, 16)
            .background(Color.mpCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(.mpBrown)
                }
            }
        }
    }

    // MARK: - Logic

    private func appendDigit(_ d: String) {
        guard pin.count < 4 else { return }
        pin += d
        if pin.count == 4 { handleFourDigits() }
    }

    private func deleteDigit() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
    }

    private func handleFourDigits() {
        if isCreating {
            if !isConfirming {
                firstPIN = pin
                pin = ""
                isConfirming = true
            } else if pin == firstPIN {
                MasterPINService.create(pin: pin)
                succeedAndDismiss()
            } else {
                // Mismatch — back to step 1
                firstPIN = ""
                pin = ""
                isConfirming = false
                triggerShake()
            }
        } else {
            if MasterPINService.verify(pin) {
                succeedAndDismiss()
            } else {
                pin = ""
                triggerShake()
            }
        }
    }

    private func succeedAndDismiss() {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            onSuccess()
        }
    }

    private func triggerShake() {
        withAnimation(.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shakeOffset = 0 }
    }
}

private struct MasterPINKey: View {
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
