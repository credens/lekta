# WarehouseApp — Contexto para Claude

POS (Point of Sale) iOS nativo en SwiftUI con integración MercadoPago. App para un solo comercio: gestiona caja, escanea códigos de barras EAN-13 con la cámara, administra inventario y procesa cobros por QR MP, Point MP o efectivo.

---

## Stack

- **SwiftUI** + Swift 6 concurrency (`async/await`, `@MainActor`)
- **AVFoundation** — captura de cámara y escaneo de barcodes
- **AuthenticationServices** — OAuth 2.0 con PKCE via `ASWebAuthenticationSession`
- **CryptoKit** — AES-256-GCM para cifrar datos locales; SHA-256 para PKCE
- **Security framework** — Keychain para tokens y clave de cifrado
- **CoreImage** — generación de QR codes

---

## Estructura de archivos

```
WarehouseApp/
├── WarehouseApp/               ← Grupo raíz del target
│   ├── WarehouseAppApp.swift   ← @main, crea los 4 ViewModels como @StateObject
│   ├── ContentView.swift       ← Router: LaunchScreen → MPConnectView | HomeView
│   ├── Config.swift            ← mpClientId, mpClientSecret, mpRedirectURI
│   ├── Color+MP.swift          ← Colores de marca + Color(hex:) + ShapeStyle extensions
│   ├── Double+Currency.swift   ← arsCurrency (formato pesos argentinos)
│   └── Info.plist              ← NSCameraUsageDescription, CFBundleURLSchemes: warehouseapp
│
├── Models/
│   ├── Product.swift           ← Product (Identifiable, Codable), Variant, finalPrice
│   ├── ScanResult.swift        ← enum: product(Product) | mercadoPagoQR(String) | unknown(String)
│   └── PaymentMethod.swift     ← enum: qrMP | pointMP | cash
│
├── ViewModels/
│   ├── CheckoutViewModel.swift ← Carrito (CartItem[]), totals, clear()
│   ├── ProductViewModel.swift  ← CRUD productos, addStock/removeStock, encrypted persistence
│   ├── CajaViewModel.swift     ← Estado de caja, registrarVenta, cerrarCaja, encrypted persistence
│   └── ScannerViewModel.swift  ← AVCaptureSession, scannedCode: String?, permisos de cámara
│
├── Services/
│   ├── MPAuthService.swift     ← OAuth2 + PKCE + state param; @MainActor ObservableObject
│   ├── KeychainService.swift   ← set/get/delete tokens; kSecAttrAccessibleWhenUnlockedThisDeviceOnly
│   ├── SecureStorage.swift     ← AES-256-GCM sobre UserDefaults; clave de 256 bits en Keychain
│   ├── MercadoPagoService.swift← createPreference, checkPaymentStatus, verificarPOS, obtenerTotalPagos
│   └── BarcodeService.swift    ← isEAN13 (con checksum), isMercadoPagoQR, classify, sanitizers
│
└── Views/
    ├── Auth/
    │   └── MPConnectView.swift    ← "Conectar con MP" + "Continuar sin MP" bypass
    ├── Home/
    │   └── HomeView.swift         ← NavigationStack, 4 botones acción, stats de sesión
    ├── Cobrar/
    │   └── CobrarView.swift       ← Cámara fullscreen, ScanOverlay, TicketSheet, ManualEntrySheet
    ├── Checkout/
    │   └── CheckoutView.swift     ← QR, Point MP, Efectivo; polling de pago; confirmación
    ├── Scanner/
    │   ├── ScannerView.swift      ← Bottom sheet con resultado del scan
    │   └── CameraPreview.swift    ← UIViewRepresentable de AVCaptureVideoPreviewLayer
    ├── Products/
    │   ├── InventarioView.swift   ← Buscar por barcode o nombre, editar precio, dar de baja
    │   └── ProductDetailView.swift← Alta/edición completa de producto con variantes
    └── LaunchScreen.swift         ← Splash animado (fondo naranja, ícono barcode.viewfinder)
```

---

## Inyección de dependencias

`WarehouseAppApp` crea todos los ViewModels como `@StateObject` e inyecta por `.environmentObject()`:

```swift
@StateObject private var authService   = MPAuthService()   // @EnvironmentObject
@StateObject private var cajaVM        = CajaViewModel()   // @EnvironmentObject
@StateObject private var productVM     = ProductViewModel() // @EnvironmentObject
@StateObject private var checkoutVM    = CheckoutViewModel()// @EnvironmentObject
```

La app fuerza `.preferredColorScheme(.light)` — no soporta dark mode (colores de marca no adaptan).

---

## Flujo OAuth (MercadoPago)

1. `MPConnectView` obtiene un `UIWindow` via `WindowAccessor` (UIViewRepresentable).
2. `MPAuthService.conectar(from:)` genera PKCE verifier+challenge y `state` (UUID).
3. `ASWebAuthenticationSession` abre `https://auth.mercadopago.com.ar/authorization`.
4. MP redirige a `https://credens.github.io/mp-redirect/` (GitHub Pages relay en HTTPS).
5. El relay hace JS redirect a `warehouseapp://auth?code=...&state=...`.
6. La sesión intercepta el callback, valida `state`, extrae `code`.
7. POST a `https://api.mercadopago.com/oauth/token` con form-encoded body:
   `client_id`, `client_secret`, `code`, `redirect_uri`, `grant_type=authorization_code`, `code_verifier`.
8. Tokens guardados en Keychain con `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

**Bypass de auth**: botón "Continuar sin MP" → `KeychainService.skipMPAuth = true` → `isAuthenticated = true`.
Para resetear: `desconectar()` borra todo el Keychain incluyendo el flag de bypass.

---

## Credenciales (Config.swift)

```swift
static let mpClientId     = "6565886142165164"
static let mpClientSecret = "MOVE_TO_BACKEND"
static let mpRedirectURI  = "https://credens.github.io/mp-redirect/"
```

> ⚠️ El client_secret en el binario es una limitación conocida de OAuth en móvil. La mitigación correcta es un backend proxy. PKCE + state parameter están implementados.

---

## Seguridad implementada

| Área | Solución |
|------|----------|
| Tokens MP | Keychain con `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| Flag skipAuth | Keychain (migrado desde UserDefaults) |
| Inventario (UserDefaults) | AES-256-GCM via `SecureStorage`; clave en Keychain |
| Datos de caja (UserDefaults) | AES-256-GCM via `SecureStorage`; struct `CajaSession` |
| OAuth CSRF | Parámetro `state` (UUID); validado en callback |
| PKCE | `code_verifier` (64 bytes random, base64url); `code_challenge` SHA-256 |
| Logging | Ningún print() con tokens, códigos de auth o datos sensibles |
| URLs de red | `cachePolicy = .reloadIgnoringLocalAndRemoteCacheData` en requests autenticados |
| Inputs | Precio max 9 dígitos; stock max 99_999; sanitizadores en `BarcodeService` |
| QR de MP | Detección por URL host parsing, whitelist de dominios |
| Force unwraps en network | Reemplazados por `guard let` + `throw URLError` |

---

## Persistencia

| Dato | Dónde | Cifrado |
|------|-------|---------|
| Access token MP | Keychain | ✅ (Keychain) |
| Refresh token MP | Keychain | ✅ (Keychain) |
| Flag skipMPAuth | Keychain | ✅ (Keychain) |
| Clave de cifrado AES | Keychain | ✅ (Keychain) |
| Inventario de productos | UserDefaults key `wh_products_v2` | ✅ AES-GCM |
| Sesión de caja activa | UserDefaults key `caja_session_v2` | ✅ AES-GCM |

---

## Colores de marca (Color+MP.swift)

```swift
.mpBrown   // #5C3A1E — texto principal
.mpAmber   // #F59E0B — degradado inicio
.mpOrange  // #FF6B35 — degradado fin, acento
.mpYellow  // #FFD60A — scan line, avisos
.mpGreen   // #22C55E — éxito, caja abierta
.mpDanger  // #EF4444 — errores, eliminar
.mpCream   // #FFF8F0 — fondo general
.mpSand    // #FEF3C7 — fondo de cards secundarias
```

Todos disponibles con dot-syntax en `foregroundStyle` via `ShapeStyle where Self == Color`.

---

## Ícono de la app

Generado programáticamente con CoreGraphics (script `/tmp/gen_icon.swift`).
Ubicación: `Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024).
Diseño: degradado naranja, 4 corner brackets de viewfinder, barras de código EAN, scan line ámbar.

---

## Pendientes / próximos pasos conocidos

- [ ] Integrar botón "Nuevo cobro" en `CobrarView` (items persisten al volver a Home, pero falta confirmación al presionar "Inicio" con carrito no vacío)
- [ ] Refresh automático de token MP (el `mpExpiresAt` se guarda pero no se usa para refrescar)
- [ ] Validar `code_challenge` length (RFC 7636 requiere 43–128 chars; base64url de 64 bytes random = 86 chars ✅)
- [ ] Backend proxy para mover el intercambio de token fuera del cliente
- [ ] Certificate pinning para llamadas a `api.mercadopago.com`
- [ ] Point MP: pantalla de "próximamente disponible" — integración real pendiente

---

## Convenciones de código

- **Swift 6 concurrency**: nada de Combine salvo donde ya existe. Preferir `async/await`.
- **No dark mode**: `.preferredColorScheme(.light)` global.
- **Colores**: siempre `.mpXxx` (nunca `Color(hex:)` en las views).
- **Formato de precios**: `value.arsCurrency` (extension en `Double+Currency.swift`).
- **onChange**: firma de 2 parámetros `{ _, newValue in }` (iOS 17+).
- **No comments** salvo WHY no obvio.
- **Sin force unwrap** en código de red.
