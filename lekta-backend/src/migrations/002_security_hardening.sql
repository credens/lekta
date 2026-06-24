CREATE TABLE IF NOT EXISTS businesses (
  id TEXT PRIMARY KEY,
  name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO businesses (id, name)
VALUES ('default', 'default')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE mercado_pago_accounts
  ADD COLUMN IF NOT EXISTS business_id TEXT;

UPDATE mercado_pago_accounts
SET business_id = 'default'
WHERE business_id IS NULL;

ALTER TABLE mercado_pago_accounts
  ALTER COLUMN business_id SET DEFAULT 'default',
  ALTER COLUMN business_id SET NOT NULL,
  ALTER COLUMN access_token DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS encrypted_access_token TEXT,
  ADD COLUMN IF NOT EXISTS encrypted_refresh_token TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_mp_accounts_business'
  ) THEN
    ALTER TABLE mercado_pago_accounts
      ADD CONSTRAINT fk_mp_accounts_business
      FOREIGN KEY (business_id) REFERENCES businesses(id);
  END IF;
END $$;

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS business_id TEXT;

UPDATE orders
SET business_id = 'default'
WHERE business_id IS NULL;

ALTER TABLE orders
  ALTER COLUMN business_id SET DEFAULT 'default',
  ALTER COLUMN business_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_orders_business'
  ) THEN
    ALTER TABLE orders
      ADD CONSTRAINT fk_orders_business
      FOREIGN KEY (business_id) REFERENCES businesses(id);
  END IF;
END $$;

ALTER TABLE mp_webhook_events
  ADD COLUMN IF NOT EXISTS processed BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS app_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id TEXT NOT NULL REFERENCES businesses(id),
  device_id TEXT,
  operator_id TEXT,
  refresh_token_hash TEXT UNIQUE NOT NULL,
  revoked_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mp_accounts_business_id ON mercado_pago_accounts(business_id);
CREATE INDEX IF NOT EXISTS idx_orders_business_id ON orders(business_id);
CREATE INDEX IF NOT EXISTS idx_app_sessions_business_id ON app_sessions(business_id);
CREATE INDEX IF NOT EXISTS idx_app_sessions_refresh_token_hash ON app_sessions(refresh_token_hash);
CREATE INDEX IF NOT EXISTS idx_app_sessions_active ON app_sessions(business_id, expires_at) WHERE revoked_at IS NULL;

DROP TRIGGER IF EXISTS trg_businesses_updated_at ON businesses;
CREATE TRIGGER trg_businesses_updated_at
BEFORE UPDATE ON businesses
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_app_sessions_updated_at ON app_sessions;
CREATE TRIGGER trg_app_sessions_updated_at
BEFORE UPDATE ON app_sessions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
