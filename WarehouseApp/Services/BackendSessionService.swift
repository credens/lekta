import Foundation

enum BackendSessionService {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackIsoFormatter = ISO8601DateFormatter()
    private static var sessionTask: Task<String, Error>?

    static func authorize(_ request: inout URLRequest) async throws {
        let token = try await validAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private static func validAccessToken() async throws -> String {
        if let token = KeychainService.get(.backendAccessToken),
           let expiresAt = KeychainService.get(.backendAccessTokenExpiresAt),
           !isExpired(expiresAt, leeway: 60) {
            return token
        }

        if let task = sessionTask {
            return try await task.value
        }

        let task = Task<String, Error> {
            if KeychainService.get(.backendRefreshToken) != nil {
                do {
                    return try await refreshSession()
                } catch {
                    clearSession()
                }
            }
            return try await createSession()
        }
        sessionTask = task
        defer { sessionTask = nil }
        return try await task.value
    }

    private static func createSession() async throws -> String {
        let url = Config.backendBaseURL
            .appendingPathComponent("api/auth/session")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.backendBootstrapToken, forHTTPHeaderField: "x-bootstrap-token")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.httpBody = try JSONEncoder().encode(
            BackendSessionRequest(
                businessID: Config.backendBusinessID,
                deviceID: deviceID(),
                operatorID: nil
            )
        )

        let response: BackendSessionResponse = try await send(request)
        save(response)
        return response.accessToken
    }

    private static func refreshSession() async throws -> String {
        guard let refreshToken = KeychainService.get(.backendRefreshToken) else {
            throw URLError(.userAuthenticationRequired)
        }

        let url = Config.backendBaseURL
            .appendingPathComponent("api/auth/refresh")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.httpBody = try JSONEncoder().encode(BackendRefreshRequest(refreshToken: refreshToken))

        let response: BackendSessionResponse = try await send(request)
        save(response)
        return response.accessToken
    }

    private static func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await SecureNetworkTransport.shared.data(
            for: request,
            pinning: .backend
        )
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            throw BackendServiceError.invalidResponse(statusCode: http.statusCode)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private static func save(_ response: BackendSessionResponse) {
        KeychainService.set(response.accessToken, for: .backendAccessToken)
        KeychainService.set(response.accessTokenExpiresAt, for: .backendAccessTokenExpiresAt)
        KeychainService.set(response.refreshToken, for: .backendRefreshToken)
        KeychainService.set(response.refreshTokenExpiresAt, for: .backendRefreshTokenExpiresAt)
        KeychainService.set(response.businessID, for: .backendBusinessId)
    }

    private static func clearSession() {
        KeychainService.delete(.backendAccessToken)
        KeychainService.delete(.backendAccessTokenExpiresAt)
        KeychainService.delete(.backendRefreshToken)
        KeychainService.delete(.backendRefreshTokenExpiresAt)
        KeychainService.delete(.backendBusinessId)
    }

    private static func isExpired(_ value: String, leeway: TimeInterval) -> Bool {
        let date = isoFormatter.date(from: value) ?? fallbackIsoFormatter.date(from: value)
        guard let date else { return true }
        return date.timeIntervalSinceNow <= leeway
    }

    private static func deviceID() -> String {
        if let existing = KeychainService.get(.backendDeviceId) {
            return existing
        }
        let generated = "ios_\(UUID().uuidString)"
        KeychainService.set(generated, for: .backendDeviceId)
        return generated
    }
}

private struct BackendSessionRequest: Encodable {
    let businessID: String
    let deviceID: String
    let operatorID: String?

    enum CodingKeys: String, CodingKey {
        case businessID = "business_id"
        case deviceID = "device_id"
        case operatorID = "operator_id"
    }
}

private struct BackendRefreshRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct BackendSessionResponse: Decodable {
    let accessToken: String
    let accessTokenExpiresAt: String
    let refreshToken: String
    let refreshTokenExpiresAt: String
    let businessID: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case accessTokenExpiresAt = "access_token_expires_at"
        case refreshToken = "refresh_token"
        case refreshTokenExpiresAt = "refresh_token_expires_at"
        case businessID = "business_id"
    }
}
