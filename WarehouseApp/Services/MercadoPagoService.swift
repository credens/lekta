import Foundation

enum MercadoPagoService {
    // MARK: - Verify Mercado Pago account is connected in backend

    static func verificarPOS() async throws {
        let url = Config.backendBaseURL
            .appendingPathComponent("api/mp/account/status")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        try await BackendSessionService.authorize(&request)

        let (_, response) = try await SecureNetworkTransport.shared.data(
            for: request,
            pinning: .backend
        )
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Total of approved payments since a date

    static func obtenerTotalPagos(desde: Date) async throws -> Double {
        let formatter = ISO8601DateFormatter()
        var components = URLComponents(
            url: Config.backendBaseURL.appendingPathComponent("api/mp/payments/total"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            .init(name: "begin_date", value: formatter.string(from: desde)),
            .init(name: "end_date", value: formatter.string(from: Date()))
        ]
        guard let url = components?.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        try await BackendSessionService.authorize(&request)

        let (data, response) = try await SecureNetworkTransport.shared.data(
            for: request,
            pinning: .backend
        )
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct PaymentsTotalResponse: Decodable {
            let totalAmount: Double
            enum CodingKeys: String, CodingKey { case totalAmount = "total_amount" }
        }

        let decoded = try JSONDecoder().decode(PaymentsTotalResponse.self, from: data)
        return decoded.totalAmount
    }
}
