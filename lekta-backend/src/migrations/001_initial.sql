CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE mercado_pago_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mp_user_id TEXT UNIQUE NOT NULL,
  access_token TEXT NOT NULL,
  refresh_token TEXT,
  expires_at TIMESTAMPTZ,
  scopes TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE orders (
  id TEXT PRIMARY KEY,
  external_reference TEXT UNIQUE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled', 'expired')),
  total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
  currency TEXT NOT NULL DEFAULT 'ARS',
  operator_id TEXT,
  cash_session_id TEXT,
  device_id TEXT,
  mp_account_id UUID REFERENCES mercado_pago_accounts(id),
  mp_preference_id TEXT,
  mp_payment_id TEXT,
  mp_status TEXT,
  status_detail TEXT,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  barcode TEXT,
  title TEXT NOT NULL,
  unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
  quantity INTEGER NOT NULL CHECK (quantity > 0)
);

CREATE TABLE mp_webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic TEXT,
  resource_id TEXT,
  action TEXT,
  idempotency_key TEXT UNIQUE,
  raw_payload JSONB NOT NULL,
  processed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'received',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_orders_external_reference ON orders(external_reference);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_mp_webhook_events_resource_id ON mp_webhook_events(resource_id);
CREATE INDEX idx_mp_webhook_events_idempotency_key ON mp_webhook_events(idempotency_key);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_mp_accounts_updated_at
BEFORE UPDATE ON mercado_pago_accounts
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
