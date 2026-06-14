import Foundation
import AuthenticationServices

/// Maneja el flujo OAuth 2.0 con MercadoPago.
/// El usuario ve el login de MP una sola vez. El token se guarda en Keychain.
@MainActor
class MPAuthService: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var webAuthSession: ASWebAuthenticationSession?
    private var presentationAnchor: ASPresentationAnchor?

    // MP OAuth endpoints
    private let authURL    = "https://auth.mercadopago.com.ar/authorization"
    private let tokenURL   = "https://api.mercadopago.com/oauth/token"
    private let callbackScheme = "warehouseapp"

    override init() {
        super.init()
        isAuthenticated = KeychainService.hasMPToken
    }

    // MARK: - Conectar

    func conectar(from anchor: ASPresentationAnchor) {
        presentationAnchor = anchor
        errorMessage = nil

        var components = URLComponents(string: authURL)!
        components.queryItems = [
            .init(name: "client_id",     value: Config.mpClientId),
            .init(name: "response_type", value: "code"),
            .init(name: "platform_id",   value: "mp"),
            .init(name: "redirect_uri",  value: "\(callbackScheme)://auth")
        ]
        guard let url = components.url else { return }

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            guard let self else { return }
            if let error {
                // Usuario canceló — no es un error real
                if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                    self.errorMessage = "Error al conectar: \(error.localizedDescription)"
                }
                return
            }
            guard let callbackURL,
                  let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value else {
                self.errorMessage = "No se recibió el código de autorización."
                return
            }
            Task { await self.exchangeCode(code) }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false  // reutiliza sesión guardada de MP
        webAuthSession = session
        isLoading = true
        session.start()
    }

    // MARK: - Intercambiar código por token

    private func exchangeCode(_ code: String) async {
        defer { isLoading = false }

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "client_id":     Config.mpClientId,
            "client_secret": Config.mpClientSecret,
            "code":          code,
            "redirect_uri":  "\(callbackScheme)://auth",
            "grant_type":    "authorization_code"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                errorMessage = "Error del servidor al obtener el token."
                return
            }
            let decoded = try JSONDecoder().decode(MPTokenResponse.self, from: data)
            saveToken(decoded)
            isAuthenticated = true
        } catch {
            errorMessage = "No se pudo completar la autenticación."
        }
    }

    // MARK: - Guardar en Keychain

    private func saveToken(_ response: MPTokenResponse) {
        KeychainService.set(response.accessToken,  for: .mpAccessToken)
        KeychainService.set(response.refreshToken, for: .mpRefreshToken)
        KeychainService.set(String(response.userId), for: .mpUserId)
        // Calcular fecha de expiración
        let expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        KeychainService.set(String(expiresAt.timeIntervalSince1970), for: .mpExpiresAt)
    }

    // MARK: - Renovar token (si expiró)

    func refreshIfNeeded() async {
        guard let expiresAtStr = KeychainService.get(.mpExpiresAt),
              let expiresAt = Double(expiresAtStr),
              Date().timeIntervalSince1970 > expiresAt - 300,  // renueva 5 min antes
              let refreshToken = KeychainService.get(.mpRefreshToken) else { return }

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "client_id":     Config.mpClientId,
            "client_secret": Config.mpClientSecret,
            "refresh_token": refreshToken,
            "grant_type":    "refresh_token"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode(MPTokenResponse.self, from: data) else { return }
        saveToken(decoded)
    }

    // MARK: - Desconectar

    func desconectar() {
        KeychainService.deleteAll()
        isAuthenticated = false
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension MPAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Acceso seguro al anchor almacenado en init
        MainActor.assumeIsolated { presentationAnchor ?? UIWindow() }
    }
}

// MARK: - MP Token Response model

private struct MPTokenResponse: Codable {
    let accessToken:  String
    let refreshToken: String
    let expiresIn:    Int
    let userId:       Int

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
        case userId       = "user_id"
    }
}
