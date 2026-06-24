import Foundation

enum Config {
    static let mpClientId = "6565886142165164"
    static let backendBaseURL = URL(string: "https://api.tudominio.com")!

    // URI registrada en Mercado Pago para el inicio del flujo OAuth.
    static let mpRedirectURI = "https://credens.github.io/mp-redirect/"

    static let marketplaceFeePercent = 2.5
}
