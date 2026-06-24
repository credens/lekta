import Foundation

/// Credenciales de la app. Completar con los datos de tu aplicación en
/// developers.mercadopago.com → Mis aplicaciones → Credenciales.
///
/// - mpClientId:     "App ID" (público, va en el código)
/// - mpClientSecret: "Client Secret" (solo backend; no guardar en clientes moviles)
enum Config {
    static let mpClientId:     String = "6565886142165164"
    static let mpClientSecret: String = "MOVE_TO_BACKEND"
}
