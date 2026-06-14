import Foundation
import Combine

@MainActor
class OperadorViewModel: ObservableObject {
    @Published private(set) var operadores: [Operador] = []

    private let key = "operadores_v1"

    init() { load() }

    var activeOperadores: [Operador] { operadores.filter { $0.isActive } }

    func add(name: String, pin: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, pin.count == 4 else { return }
        let op = Operador(name: name.trimmingCharacters(in: .whitespaces),
                          pinHash: Operador.hashPIN(pin))
        operadores.append(op)
        save()
    }

    func deactivate(_ operador: Operador) {
        guard let idx = operadores.firstIndex(where: { $0.id == operador.id }) else { return }
        operadores[idx].isActive = false
        save()
    }

    func reactivate(_ operador: Operador) {
        guard let idx = operadores.firstIndex(where: { $0.id == operador.id }) else { return }
        operadores[idx].isActive = true
        save()
    }

    func login(id: UUID, pin: String) -> Operador? {
        guard let op = operadores.first(where: { $0.id == id && $0.isActive }),
              op.verifyPIN(pin) else { return nil }
        return op
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded: [Operador] = SecureStorage.decryptCodable(data) else { return }
        operadores = decoded
    }

    private func save() {
        guard let data: Data = SecureStorage.encryptCodable(operadores) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
