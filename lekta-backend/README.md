# Lekta Backend

Backend minimo para que la app no hable directo con Mercado Pago.

## Que resuelve

- Sesiones app/backend con access token corto y refresh token rotado.
- Exchange OAuth con Mercado Pago desde servidor.
- Tokens de Mercado Pago cifrados en base de datos.
- Ordenes internas con `external_reference` unico y `business_id`.
- Creacion de preferences con `notification_url` desde backend.
- Webhook publico que no confia en el payload: consulta el pago real a Mercado Pago antes de aprobar una orden.
- Endpoint de status para polling desde la app.
- Logs sanitizados, rate limit y opcion de exigir HTTPS detras de nginx.

## Setup

```bash
cd lekta-backend
cp .env.example .env
npm install
npm run migrate
npm run dev
```

Variables principales:

- `DATABASE_URL`: Postgres del backend.
- `JWT_SECRET`: firma de access tokens app/backend.
- `APP_BOOTSTRAP_TOKEN`: token inicial para crear la primera sesion desde la app.
- `TOKEN_ENCRYPTION_KEY`: clave AES-256-GCM para tokens de Mercado Pago.
- `MP_CLIENT_ID`: client id de la app Mercado Pago.
- `MP_CLIENT_SECRET`: secreto de la app Mercado Pago. Nunca va al cliente.
- `MP_REDIRECT_URI`: redirect usado por la app durante OAuth.
- `PUBLIC_BASE_URL`: URL publica HTTPS del backend.
- `MP_NOTIFICATION_URL`: opcional. Si no se define, usa `${PUBLIC_BASE_URL}/api/webhooks/mercadopago`.
- `ENFORCE_HTTPS`: usar `true` en produccion detras de nginx con `X-Forwarded-Proto=https`.

## Auth app/backend

Antes de usar checkout u OAuth, la app crea una sesion:

### `POST /api/auth/session`

Header:

```http
x-bootstrap-token: APP_BOOTSTRAP_TOKEN
```

Body:

```json
{
  "business_id": "default",
  "device_id": "ios-device-1",
  "operator_id": "op_123"
}
```

Respuesta:

```json
{
  "access_token": "...",
  "access_token_expires_at": "2026-06-24T12:00:00.000Z",
  "refresh_token": "...",
  "refresh_token_expires_at": "2026-07-24T12:00:00.000Z",
  "business_id": "default"
}
```

Usar `Authorization: Bearer <access_token>` en:

- `POST /api/mp/oauth/exchange`
- `GET /api/mp/account/status`
- `GET /api/mp/payments/total?begin_date=...`
- `POST /api/checkout/orders`
- `POST /api/checkout/orders/:id/preference`
- `GET /api/checkout/orders/:id/status`

Renovar con `POST /api/auth/refresh` enviando `refresh_token`. El refresh token viejo queda revocado y se devuelve uno nuevo.

## Endpoints Mercado Pago

### `POST /api/mp/oauth/exchange`

Recibe el `code` y `code_verifier` desde la app. El backend llama a Mercado Pago y guarda tokens cifrados.

```json
{
  "code": "TG-...",
  "code_verifier": "pkce-verifier",
  "redirect_uri": "warehouseapp://auth"
}
```

Respuesta:

```json
{
  "mp_account_id": "uuid",
  "mp_user_id": "123456",
  "expires_at": "2026-06-24T12:00:00.000Z",
  "scopes": ["offline_access", "read", "write"]
}
```

### `GET /api/mp/account/status`

Devuelve estado basico de la cuenta conectada consultando Mercado Pago con el token backend.

### `GET /api/mp/payments/total?begin_date=2026-06-01T00:00:00.000Z`

Devuelve total aprobado desde `begin_date`. Soporta `end_date` opcional.

## Endpoints Checkout

### `POST /api/checkout/orders`

Crea una orden local `pending`.

```json
{
  "items": [
    {
      "barcode": "7791234567890",
      "name": "Producto",
      "unit_price": 2500,
      "quantity": 2
    }
  ],
  "operator_id": "op_123",
  "cash_session_id": "cash_456",
  "device_id": "ios-device-1"
}
```

Respuesta:

```json
{
  "order_id": "ord_123",
  "external_reference": "lekta-ord_123",
  "status": "pending",
  "total_amount": 5000
}
```

### `POST /api/checkout/orders/:id/preference`

Crea la preference de Mercado Pago para la orden.

```json
{
  "success_url": null
}
```

Respuesta:

```json
{
  "order_id": "ord_123",
  "preference_id": "123456789-xxxx",
  "init_point": "https://www.mercadopago.com/...",
  "sandbox_init_point": "https://sandbox.mercadopago.com/..."
}
```

### `GET /api/checkout/orders/:id/status`

Endpoint para polling desde la app mientras se muestra el QR.

```json
{
  "order_id": "ord_123",
  "status": "approved",
  "status_detail": "accredited",
  "mp_payment_id": "99887766"
}
```

Estados posibles:

- `pending`
- `approved`
- `rejected`
- `cancelled`
- `expired`

La app solo debe descontar stock, registrar venta y cerrar checkout cuando reciba `approved`.

### `POST /api/webhooks/mercadopago`

Endpoint publico HTTPS para Mercado Pago. Guarda el evento crudo con `idempotency_key`, ignora duplicados, extrae payment id, consulta `/v1/payments/:id` con el access token guardado, busca la orden por `external_reference` y actualiza la orden.

## Notas

- Toda credencial de Mercado Pago queda solo en backend y se guarda cifrada.
- La app no crea preferences ni consulta Mercado Pago para saber si se pago.
- Si ya habia cuentas conectadas con tokens sin cifrar, hay que reconectar Mercado Pago para generar filas con `encrypted_access_token`.
- En nginx, configurar TLS y reenviar `X-Forwarded-Proto https` al proceso Node.
