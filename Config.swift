import Foundation

/// Credenciales de la app. Completar con los datos de tu aplicación en
/// developers.mercadopago.com → Mis aplicaciones → Credenciales.
///
/// - mpClientId:     "App ID" (público, va en el código)
/// - mpClientSecret: "Client Secret" (semiprivado — no publicar en repos públicos)
enum Config {
    static let mpClientId:     String = "6565886142165164"
    static let mpClientSecret: String = "APP_USR-594991925555806-060618-aaebaf038a12400794e841ab29ec1697-3456266918"
}
