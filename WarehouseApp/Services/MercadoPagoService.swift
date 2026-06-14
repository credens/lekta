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

enum MercadoPagoService {
    private static var accessToken: String {
        KeychainService.mpAccessToken ?? ""
    }

    private static let baseURL = "https://api.mercadopago.com"

    // MARK: - Create preference

    static func createPreference(items: [CartItem]) async throws -> PreferenceResponse {
        guard let url = URL(string: "\(baseURL)/checkout/preferences") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",       forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let mpItems = items.map { item -> [String: Any] in [
            "title":      item.product.name,
            "quantity":   item.quantity,
            "unit_price": item.product.finalPrice,
            "currency_id": "ARS"
        ]}

        let total = items.reduce(0.0) { $0 + $1.product.finalPrice * Double($1.quantity) }
        let marketplaceFee = floor(total * Config.marketplaceFeePercent / 100.0 * 100) / 100

        var body: [String: Any] = ["items": mpItems]
        body["marketplace_fee"] = marketplaceFee
        body["marketplace"] = Config.mpClientId

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PreferenceResponse.self, from: data)
    }

    // MARK: - Check payment status

    static func checkPaymentStatus(preferenceId: String) async throws -> PaymentStatus {
        guard preferenceId.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }),
              let url = URL(string: "\(baseURL)/checkout/preferences/\(preferenceId)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct StatusResponse: Codable { let status: String? }
        let decoded = try JSONDecoder().decode(StatusResponse.self, from: data)
        return PaymentStatus(rawValue: decoded.status ?? "pending") ?? .pending
    }

    // MARK: - Verify POS is active

    static func verificarPOS() async throws {
        guard let url = URL(string: "\(baseURL)/pos") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Total of approved payments since a date

    static func obtenerTotalPagos(desde: Date) async throws -> Double {
        let formatter = ISO8601DateFormatter()
        var components = URLComponents(string: "\(baseURL)/v1/payments/search")
        components?.queryItems = [
            .init(name: "status",     value: "approved"),
            .init(name: "begin_date", value: formatter.string(from: desde)),
            .init(name: "end_date",   value: formatter.string(from: Date())),
            .init(name: "limit",      value: "100")
        ]
        guard let url = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct Payment: Codable {
            let transactionAmount: Double
            enum CodingKeys: String, CodingKey { case transactionAmount = "transaction_amount" }
        }
        struct SearchResult: Codable { let results: [Payment] }

        let decoded = try JSONDecoder().decode(SearchResult.self, from: data)
        return decoded.results.reduce(0) { $0 + $1.transactionAmount }
    }
}
