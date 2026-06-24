import Foundation
import AuthenticationServices
import CryptoKit
import Combine

@MainActor
class MPAuthService: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var webAuthSession: ASWebAuthenticationSession?
    private var presentationAnchor: ASPresentationAnchor?
    private var codeVerifier: String?
    private var oauthState: String?

    private let authURL        = "https://auth.mercadopago.com.ar/authorization"
    private let callbackScheme = "warehouseapp"

    override init() {
        super.init()
        // Migrate legacy UserDefaults skip flag to Keychain (one-time)
        let legacyKey = "warehouseapp_skip_mp_auth"
        if UserDefaults.standard.bool(forKey: legacyKey) {
            KeychainService.skipMPAuth = true
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }
        isAuthenticated = KeychainService.hasMPConnection || KeychainService.skipMPAuth
    }

    // MARK: - Skip authentication (bypass mode for testing)

    func skipAuthentication() {
        KeychainService.skipMPAuth = true
        isAuthenticated = true
    }

    // MARK: - Connect via OAuth + PKCE + State

    func conectar(from anchor: ASPresentationAnchor) {
        presentationAnchor = anchor
        errorMessage = nil

        let verifier  = makeCodeVerifier()
        let challenge = makeCodeChallenge(from: verifier)
        let state     = UUID().uuidString
        codeVerifier  = verifier
        oauthState    = state

        var components = URLComponents(string: authURL)!
        components.queryItems = [
            .init(name: "client_id",             value: Config.mpClientId),
            .init(name: "response_type",         value: "code"),
            .init(name: "redirect_uri",          value: Config.mpRedirectURI),
            .init(name: "code_challenge",        value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state",                 value: state)
        ]
        guard let url = components.url else { return }

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            guard let self else { return }

            if let error {
                if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                    self.errorMessage = "Error al conectar con MercadoPago."
                }
                return
            }

            guard let callbackURL else {
                self.errorMessage = "No se recibió respuesta de MercadoPago."
                return
            }

            let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems

            // Validate state to prevent CSRF
            guard let returnedState = queryItems?.first(where: { $0.name == "state" })?.value,
                  returnedState == self.oauthState else {
                self.errorMessage = "Error de seguridad en el proceso de autenticación."
                self.oauthState = nil
                return
            }
            self.oauthState = nil

            if let mpError = queryItems?.first(where: { $0.name == "error" })?.value {
                let desc = queryItems?.first(where: { $0.name == "error_description" })?.value ?? ""
                self.errorMessage = "MercadoPago: \(desc.isEmpty ? mpError : desc)"
                return
            }

            guard let code = queryItems?.first(where: { $0.name == "code" })?.value else {
                self.errorMessage = "No se recibió el código de autorización."
                return
            }

            Task { await self.exchangeCode(code) }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        webAuthSession = session
        isLoading = true
        session.start()
    }

    // MARK: - Exchange code via backend

    private func exchangeCode(_ code: String) async {
        defer { isLoading = false }

        guard let verifier = codeVerifier else {
            errorMessage = "Error interno en el proceso de autenticación."
            return
        }
        codeVerifier = nil

        do {
            let decoded = try await BackendAuthService.exchangeOAuthCode(
                code: code,
                codeVerifier: verifier
            )
            saveToken(decoded)
            KeychainService.skipMPAuth = false
            isAuthenticated = true
        } catch {
            errorMessage = "No se pudo completar la autenticación."
        }
    }

    // MARK: - PKCE helpers

    private func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makeCodeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Save tokens to Keychain

    private func saveToken(_ response: OAuthExchangeResponse) {
        KeychainService.set(response.mpAccountID, for: .mpAccountId)
        KeychainService.set(response.mpUserID, for: .mpUserId)
        KeychainService.set(response.expiresAt, for: .mpExpiresAt)
    }

    // MARK: - Disconnect

    func desconectar() {
        KeychainService.deleteAll()
        isAuthenticated = false
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension MPAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            if let anchor = presentationAnchor { return anchor }
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let window = scenes.flatMap({ $0.windows }).first { return window }
            if let scene = scenes.first { return UIWindow(windowScene: scene) }
            preconditionFailure("No UIWindowScene available")
        }
    }
}
