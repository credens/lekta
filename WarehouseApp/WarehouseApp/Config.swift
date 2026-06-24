import Foundation

enum Config {
    static let mpClientId = "6565886142165164"
    static let backendBaseURL = URL(string: "https://lekta.com.ar")!
    static let backendBusinessID = "default"
    static let backendBootstrapToken = "REPLACE_WITH_BACKEND_BOOTSTRAP_TOKEN"
    static let backendPinnedCertificateSHA256 = [
        "REPLACE_WITH_REAL_CERT_SHA256_BASE64"
    ]

    // URI registrada en Mercado Pago para el inicio del flujo OAuth.
    static let mpRedirectURI = "https://credens.github.io/mp-redirect/"

    static let marketplaceFeePercent = 2.5
}
