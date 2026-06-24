import Foundation

enum BackendAuthService {
    static func exchangeOAuthCode(code: String, codeVerifier: String) async throws -> OAuthExchangeResponse {
        let url = Config.backendBaseURL
            .appendingPathComponent("api/mp/oauth/exchange")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        try await BackendSessionService.authorize(&request)
        request.httpBody = try JSONEncoder().encode(
            OAuthExchangeRequest(
                code: code,
                codeVerifier: codeVerifier,
                redirectURI: Config.mpRedirectURI
            )
        )

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

        return try JSONDecoder().decode(OAuthExchangeResponse.self, from: data)
    }
}

struct OAuthExchangeRequest: Encodable {
    let code: String
    let codeVerifier: String
    let redirectURI: String

    enum CodingKeys: String, CodingKey {
        case code
        case codeVerifier = "code_verifier"
        case redirectURI = "redirect_uri"
    }
}

struct OAuthExchangeResponse: Decodable {
    let mpAccountID: String
    let mpUserID: String
    let expiresAt: String
    let scopes: [String]

    enum CodingKeys: String, CodingKey {
        case mpAccountID = "mp_account_id"
        case mpUserID = "mp_user_id"
        case expiresAt = "expires_at"
        case scopes
    }
}
