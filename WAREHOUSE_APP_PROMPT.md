# WarehouseApp — iOS Native App

## Objetivo
App nativa iPhone para gestión de depósito/almacén con escaneo de códigos de barras y cobro via MercadoPago.

---

## Stack
- **SwiftUI** (iOS 17+)
- **AVFoundation** — scanner de cámara
- **UserDefaults** (JSON encode/decode) — persistencia local, migrar a CoreData en v2
- **URLSession** — integración MercadoPago API

---

## Estructura de archivos a crear

```
WarehouseApp/
├── WarehouseApp.swift
├── Models/
│   ├── Product.swift
│   └── ScanResult.swift
├── ViewModels/
│   ├── ScannerViewModel.swift
│   ├── ProductViewModel.swift
│   └── CheckoutViewModel.swift
├── Views/
│   ├── MainTabView.swift
│   ├── Scanner/
│   │   ├── ScannerView.swift
│   │   └── CameraPreview.swift
│   ├── Products/
│   │   ├── ProductListView.swift
│   │   └── ProductDetailView.swift
│   └── Checkout/
│       └── CheckoutView.swift
└── Services/
    ├── BarcodeService.swift
    └── MercadoPagoService.swift
```

---

## Design System — Paleta de colores (warm, similar a MercadoPago)

```swift
extension Color {
    static let mpAmber   = Color(hex: "FF9A00")
    static let mpOrange  = Color(hex: "FF6B35")
    static let mpYellow  = Color(hex: "FFE600")
    static let mpCream   = Color(hex: "FFF8F0")
    static let mpSand    = Color(hex: "F5E6D3")
    static let mpBrown   = Color(hex: "8B5E3C")
    static let mpGreen   = Color(hex: "00B560")
    static let mpDanger  = Color(hex: "FF4444")
}
```

Botones primarios: gradiente `mpAmber → mpOrange`, cornerRadius 16, sombra naranja.  
Fondos: `mpCream` para pantalla principal, `white` para cards.  
Fuente: SF Rounded (system).

---

## Modelos

### Product.swift
```swift
struct Product: Identifiable, Codable {
    var id: UUID = UUID()
    var barcode: String          // EAN-13
    var name: String
    var price: Double
    var stock: Int
    var variants: [Variant]
    var discount: Double         // 0.0–1.0
    var category: String

    struct Variant: Identifiable, Codable {
        var id: UUID = UUID()
        var name: String         // "Color", "Talle"
        var value: String        // "Rojo", "XL"
        var priceDelta: Double
        var stock: Int
    }

    var finalPrice: Double { price * (1 - discount) }
}
```

### ScanResult.swift
```swift
enum ScanResult {
    case product(Product)
    case mercadoPagoQR(String)
    case unknown(String)
}
```

---

## ViewModels

### ScannerViewModel.swift
- `AVCaptureSession` con `AVCaptureMetadataOutput`
- Tipos: `.ean13`, `.qr`
- Al detectar: vibrar (`AudioServicesPlaySystemSound kSystemSoundID_Vibrate`), publicar `scannedCode: String?`, pausar sesión
- Métodos: `startSession()`, `stopSession()`

### ProductViewModel.swift
- `@Published var products: [Product]`
- Persiste en `UserDefaults` clave `"wh_products"` via `JSONEncoder/Decoder`
- Métodos: `find(barcode:) -> Product?`, `upsert(_:)`, `delete(_:)`, `addStock(barcode:qty:)`, `removeStock(barcode:qty:)`

### CheckoutViewModel.swift
```swift
struct CartItem: Identifiable {
    var id: UUID = UUID()
    var product: Product
    var quantity: Int
    var subtotal: Double { product.finalPrice * Double(quantity) }
}
```
- `@Published var items: [CartItem]`
- Métodos: `add(product:)`, `remove(item:)`, `updateQty(item:qty:)`, `clear()`
- Computed: `total: Double`, `discount: Double`, `subtotalBeforeDiscount: Double`

---

## Vistas

### MainTabView.swift
TabView con 3 tabs:
1. `ScannerView` — icono `barcode.viewfinder`, label "Escanear"
2. `ProductListView` — icono `shippingbox`, label "Productos"
3. `CheckoutView` — icono `creditcard`, label "Cobrar"

Tint: `mpOrange`. Fondo tab bar: `.ultraThinMaterial`.

---

### ScannerView.swift
Layout:
```
┌─────────────────────────┐
│  [cámara fullscreen]    │
│    [visor con esquinas  │
│     amarillas animadas] │
│  "Apuntá al código..."  │
│  [pills: EAN-13 | QR | Stock] │
├─────────────────────────┤
│  drag handle            │
│  [product thumb] nombre │
│                barcode  │
│                precio   │
│                stock    │
│  [+ Stock]  [💳 Cobrar] │
└─────────────────────────┘
```

- Si producto no encontrado: mostrar "Crear producto" → navegar a `ProductDetailView` con barcode pre-cargado
- Pills cambian el modo de acción al confirmar scan (cobrar / sumar stock / restar stock)
- Línea de scan animada (move up/down infinito, color `mpYellow`)
- Al tocar "Cobrar": agregar al `CheckoutViewModel` y navegar al tab Cobrar

### CameraPreview.swift
`UIViewRepresentable` wrapping `AVCaptureVideoPreviewLayer`.

---

### ProductListView.swift
- `NavigationStack`
- Header: título "Productos" + botón `+` naranja
- Search bar: filtra por nombre o barcode
- Chips horizontales scrolleables: categorías dinámicas desde productos
- Lista de `ProductRow`:
  - Emoji/ícono categoría, nombre, EAN, precio, stock (rojo si < 5)
  - Badge amarillo si tiene descuento
- Footer card: valor total de stock + cantidad de productos
- Swipe to delete

### ProductDetailView.swift
Formulario para crear/editar producto:
- Campos: nombre, precio, stock, descuento (slider 0–50%), categoría
- Barcode pre-cargado si viene del scanner
- Sección "Variantes": lista editable, botón `+ Variante`
- Cada variante: nombre, valor, delta de precio, stock propio
- Guardar → `productVM.upsert(product)`

---

### CheckoutView.swift
Layout:
```
┌─────────────────────────┐
│  Header gradiente       │
│  TOTAL A COBRAR         │
│  $5.130  [🛒 3 arts]   │
├─────────────────────────┤
│  [scroll]               │
│  ARTÍCULOS              │
│  [thumb] nombre         │
│          variante  [−][n][+]  $precio │
│  ...                    │
│  ─────────────          │
│  Subtotal     $5.700    │
│  Descuentos   −$570     │
│  ──────────────────     │
│  Total        $5.130    │
│                         │
│  MÉTODO DE PAGO         │
│  [QR MP] [Point] [Efec] │
│                         │
│  [QR placeholder]       │
│  "Mostrá este código"   │
│                         │
│  [⚡ Confirmar cobro]   │
└─────────────────────────┘
```

Métodos de pago:
- **QR MP**: genera QR via MercadoPago API (ver Services)
- **Point MP**: placeholder por ahora
- **Efectivo**: confirma directo, descuenta stock

---

## Services

### BarcodeService.swift
```swift
struct BarcodeService {
    static func isEAN13(_ s: String) -> Bool {
        s.count == 13 && s.allSatisfy(\.isNumber)
    }
    static func isMercadoPagoQR(_ s: String) -> Bool {
        s.contains("mercadopago") || s.hasPrefix("https://mpago") || s.hasPrefix("https://www.mercadopago")
    }
    static func classify(_ raw: String, products: [Product]) -> ScanResult {
        if let p = products.first(where: { $0.barcode == raw }) { return .product(p) }
        if isMercadoPagoQR(raw) { return .mercadoPagoQR(raw) }
        return .unknown(raw)
    }
}
```

### MercadoPagoService.swift
```swift
// Checkout Pro — crear preferencia de pago
struct MercadoPagoService {
    static let accessToken = "YOUR_MP_ACCESS_TOKEN" // reemplazar con env var

    // POST https://api.mercadopago.com/checkout/preferences
    static func createPreference(items: [CartItem]) async throws -> PreferenceResponse

    // GET estado del pago
    static func checkPaymentStatus(preferenceId: String) async throws -> PaymentStatus
}

struct PreferenceResponse: Codable {
    let id: String
    let initPoint: String      // URL checkout web
    let sandboxInitPoint: String
}

enum PaymentStatus: String, Codable {
    case pending, approved, rejected, cancelled
}
```

QR a mostrar: generar imagen QR desde `initPoint` URL usando `CoreImage.CIFilter.qrCodeGenerator`.

---

## Info.plist — Permisos requeridos
```xml
<key>NSCameraUsageDescription</key>
<string>Necesitamos acceso a la cámara para escanear códigos de barras y QR.</string>
```

---

## Notas de implementación
- Target: iOS 17+, iPhone only (portrait)
- No usar `NavigationView`, usar `NavigationStack`
- `@EnvironmentObject var productVM: ProductViewModel` inyectado desde root
- `@EnvironmentObject var checkoutVM: CheckoutViewModel` inyectado desde root
- Usar `withAnimation(.spring())` en transiciones de resultado de scan
- Stock badge rojo cuando `stock < 5`
- Descuento badge amarillo (`mpYellow`) cuando `discount > 0`
- Todos los precios en formato `$#.###` (locale AR)

---

## Flujo principal
```
Escanear EAN-13
    → encontrado → mostrar card → [Cobrar] → agregar a checkout → ir a tab Cobrar
    → no encontrado → [Crear producto] → ProductDetailView con barcode pre-cargado

Escanear QR MP
    → parsear URL → mostrar info → confirmar pago

Tab Cobrar
    → seleccionar QR → llamar MercadoPagoService.createPreference() → generar QR → mostrar
    → cliente escanea → polling checkPaymentStatus() cada 3s → confirmar → limpiar carrito → descontar stock
```
