import Foundation

struct PreferenceResponse: Codable {
    let id: String
    let initPoint: String
    let sandboxInitPoint: String

    enum CodingKeys: String, CodingKey {
        case id
        case initPoint = "init_point"
        case sandboxInitPoint = "sandbox_init_point"
    }
}

enum PaymentStatus: String, Codable {
    case pending, approved, rejected, cancelled
}

struct MercadoPagoService {
    static var accessToken: String {
        KeychainService.mpAccessToken ?? ""
    }

    // MARK: - Create preference

    static func createPreference(items: [CartItem]) async throws -> PreferenceResponse {
        let url = URL(string: "https://api.mercadopago.com/checkout/preferences")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let mpItems = items.map { item -> [String: Any] in
            [
                "title": item.product.name,
                "quantity": item.quantity,
                "unit_price": item.product.finalPrice,
                "currency_id": "ARS"
            ]
        }
        let body: [String: Any] = ["items": mpItems]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PreferenceResponse.self, from: data)
    }

    // MARK: - Check payment status

    static func checkPaymentStatus(preferenceId: String) async throws -> PaymentStatus {
        let url = URL(string: "https://api.mercadopago.com/checkout/preferences/\(preferenceId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        struct StatusResponse: Codable {
            let status: String?
        }
        let decoded = try JSONDecoder().decode(StatusResponse.self, from: data)
        return PaymentStatus(rawValue: decoded.status ?? "pending") ?? .pending
    }

    // MARK: - Caja: verificar POS activo

    /// Verifica que el POS configurado en MP esté activo.
    /// Endpoint: GET /pos  — devuelve la lista de puntos de venta del vendedor.
    static func verificarPOS() async throws {
        let url = URL(string: "https://api.mercadopago.com/pos")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Caja: total de pagos aprobados desde una fecha

    /// Suma todos los pagos aprobados vía MP desde `desde` hasta ahora.
    /// Endpoint: GET /v1/payments/search
    static func obtenerTotalPagos(desde: Date) async throws -> Double {
        let formatter = ISO8601DateFormatter()
        let begin = formatter.string(from: desde)
        let end   = formatter.string(from: Date())

        var components = URLComponents(string: "https://api.mercadopago.com/v1/payments/search")!
        components.queryItems = [
            .init(name: "status",     value: "approved"),
            .init(name: "begin_date", value: begin),
            .init(name: "end_date",   value: end),
            .init(name: "limit",      value: "100")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        struct SearchResult: Codable {
            struct Payment: Codable {
                let transactionAmount: Double
                enum CodingKeys: String, CodingKey {
                    case transactionAmount = "transaction_amount"
                }
            }
            struct Paging: Codable { let total: Int }
            let results: [Payment]
        }

        let decoded = try JSONDecoder().decode(SearchResult.self, from: data)
        return decoded.results.reduce(0) { $0 + $1.transactionAmount }
    }
}
