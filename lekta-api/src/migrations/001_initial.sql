CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Usuarios (dueños de negocio)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  business_name TEXT NOT NULL,
  phone TEXT,
  subscription_tier TEXT NOT NULL DEFAULT 'free',
  mp_access_token TEXT,
  mp_refresh_token TEXT,
  mp_user_id TEXT,
  mp_expires_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Operadores (cajeros, empleados)
CREATE TABLE operators (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  pin_hash TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_operators_user_id ON operators(user_id);

-- Dispositivos vinculados
CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_name TEXT,
  platform TEXT NOT NULL, -- ios, android
  push_token TEXT,
  last_active TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_devices_user_id ON devices(user_id);

-- Productos
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  barcode TEXT,
  name TEXT NOT NULL,
  price DECIMAL(12,2) NOT NULL DEFAULT 0,
  stock INT NOT NULL DEFAULT 0,
  discount DECIMAL(5,4) NOT NULL DEFAULT 0,
  category TEXT NOT NULL DEFAULT '',
  variants JSONB NOT NULL DEFAULT '[]',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_products_user_id ON products(user_id);
CREATE INDEX idx_products_barcode ON products(user_id, barcode);

-- Sesiones de caja
CREATE TABLE caja_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  operator_id UUID REFERENCES operators(id) ON DELETE SET NULL,
  device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
  opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  total_ventas DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_mp DECIMAL(12,2) NOT NULL DEFAULT 0,
  total_efectivo DECIMAL(12,2) NOT NULL DEFAULT 0,
  cantidad_ventas INT NOT NULL DEFAULT 0
);

CREATE INDEX idx_caja_sessions_user_id ON caja_sessions(user_id);

-- Ventas individuales
CREATE TABLE sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  caja_session_id UUID NOT NULL REFERENCES caja_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  total DECIMAL(12,2) NOT NULL,
  payment_method TEXT NOT NULL,
  items JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sales_caja_session ON sales(caja_session_id);
CREATE INDEX idx_sales_user_created ON sales(user_id, created_at);
