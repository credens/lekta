# Lekta Backend

Backend minimo para mover Mercado Pago fuera de la app iOS/Android.

## Que resuelve

- Exchange OAuth con Mercado Pago desde servidor.
- Ordenes internas con `external_reference` unico.
- Creacion de preferences con `notification_url`.
- Webhook publico que no confia en el payload: consulta el pago real a Mercado Pago antes de aprobar una orden.
- Endpoint de status para polling desde la app.

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
- `MP_CLIENT_ID`: client id de la app Mercado Pago.
- `MP_CLIENT_SECRET`: secreto de la app Mercado Pago. Nunca va al cliente.
- `MP_REDIRECT_URI`: redirect usado por la app durante OAuth.
- `PUBLIC_BASE_URL`: URL publica HTTPS del backend.
- `MP_NOTIFICATION_URL`: opcional. Si no se define, usa `${PUBLIC_BASE_URL}/api/webhooks/mercadopago`.

## Endpoints

### `POST /api/mp/oauth/exchange`

Recibe el `code` y `code_verifier` desde la app. El backend llama a Mercado Pago y guarda tokens.

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

- Este backend asume un comercio/cuenta Mercado Pago por defecto. Si una orden no manda `mp_account_id`, se usa la cuenta conectada mas reciente.
- Los tokens quedan solo en servidor. Para produccion, usar Postgres administrado con cifrado en reposo y backups seguros; si el riesgo lo requiere, agregar cifrado de tokens a nivel aplicacion.
- El webhook debe estar expuesto por HTTPS para que Mercado Pago lo llame.
