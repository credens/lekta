import Foundation

enum BackendServiceError: Error {
    case invalidResponse(statusCode: Int)
    case missingQRURL
}

enum BackendOrderStatus: String, Codable {
    case pending
    case approved
    case rejected
    case cancelled
    case expired
}

enum BackendCheckoutService {
    static func createOrder(
        items: [CartItem],
        operatorID: String?,
        cashSessionID: String?,
        deviceID: String? = nil
    ) async throws -> CreateOrderResponse {
        let url = Config.backendBaseURL
            .appendingPathComponent("api/checkout/orders")

        let payload = CreateOrderRequest(
            items: items.map {
                BackendOrderItemPayload(
                    barcode: $0.product.barcode,
                    name: $0.product.name,
                    unitPrice: $0.product.finalPrice,
                    quantity: $0.quantity
                )
            },
            operatorID: operatorID,
            cashSessionID: cashSessionID,
            deviceID: deviceID
        )

        return try await send(requestBody: payload, to: url)
    }

    static func createPreference(orderID: String) async throws -> CreatePreferenceResponse {
        let url = Config.backendBaseURL
            .appendingPathComponent("api/checkout/orders")
            .appendingPathComponent(orderID)
            .appendingPathComponent("preference")

        return try await send(
            requestBody: CreatePreferenceRequest(successURL: nil),
            to: url
        )
    }

    static func fetchOrderStatus(orderID: String) async throws -> OrderStatusResponse {
        let url = Config.backendBaseURL
            .appendingPathComponent("api/checkout/orders")
            .appendingPathComponent(orderID)
            .appendingPathComponent("status")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            throw BackendServiceError.invalidResponse(statusCode: http.statusCode)
        }

        return try JSONDecoder().decode(OrderStatusResponse.self, from: data)
    }

    private static func send<RequestBody: Encodable, ResponseBody: Decodable>(
        requestBody: RequestBody,
        to url: URL
    ) async throws -> ResponseBody {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            throw BackendServiceError.invalidResponse(statusCode: http.statusCode)
        }

        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }
}

struct BackendOrderItemPayload: Encodable {
    let barcode: String
    let name: String
    let unitPrice: Double
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case barcode
        case name
        case unitPrice = "unit_price"
        case quantity
    }
}

struct CreateOrderRequest: Encodable {
    let items: [BackendOrderItemPayload]
    let operatorID: String?
    let cashSessionID: String?
    let deviceID: String?

    enum CodingKeys: String, CodingKey {
        case items
        case operatorID = "operator_id"
        case cashSessionID = "cash_session_id"
        case deviceID = "device_id"
    }
}

struct CreateOrderResponse: Decodable {
    let orderID: String
    let externalReference: String
    let status: BackendOrderStatus
    let totalAmount: Double

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case externalReference = "external_reference"
        case status
        case totalAmount = "total_amount"
    }
}

struct CreatePreferenceRequest: Encodable {
    let successURL: String?

    enum CodingKeys: String, CodingKey {
        case successURL = "success_url"
    }
}

struct CreatePreferenceResponse: Decodable {
    let orderID: String
    let preferenceID: String
    let initPoint: String
    let sandboxInitPoint: String?

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case preferenceID = "preference_id"
        case initPoint = "init_point"
        case sandboxInitPoint = "sandbox_init_point"
    }

    var qrURLString: String? {
        sandboxInitPoint ?? initPoint
    }
}

struct OrderStatusResponse: Decodable {
    let orderID: String
    let status: BackendOrderStatus
    let statusDetail: String?
    let mpPaymentID: String?

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case status
        case statusDetail = "status_detail"
        case mpPaymentID = "mp_payment_id"
    }
}
