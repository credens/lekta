import 'dotenv/config';

const publicBaseUrl = process.env.PUBLIC_BASE_URL?.replace(/\/$/, '');

const config = {
  port: Number(process.env.PORT || 3300),
  databaseUrl: process.env.DATABASE_URL,
  mpClientId: process.env.MP_CLIENT_ID,
  mpClientSecret: process.env.MP_CLIENT_SECRET,
  mpRedirectUri: process.env.MP_REDIRECT_URI,
  publicBaseUrl,
  mpNotificationUrl:
    process.env.MP_NOTIFICATION_URL ||
    (publicBaseUrl ? `${publicBaseUrl}/api/webhooks/mercadopago` : undefined),
  jwtSecret: process.env.JWT_SECRET,
  appBootstrapToken: process.env.APP_BOOTSTRAP_TOKEN,
  tokenEncryptionKey: process.env.TOKEN_ENCRYPTION_KEY,
  appAccessTokenSeconds: Number(process.env.APP_ACCESS_TOKEN_SECONDS || 900),
  appRefreshTokenDays: Number(process.env.APP_REFRESH_TOKEN_DAYS || 30),
  rateLimitWindowMs: Number(process.env.RATE_LIMIT_WINDOW_MS || 60000),
  rateLimitMax: Number(process.env.RATE_LIMIT_MAX || 120),
  enforceHttps: process.env.ENFORCE_HTTPS === 'true',
};

export function requireConfig(keys) {
  const missing = keys.filter(key => !config[key]);
  if (missing.length) {
    throw new Error(`Missing required config: ${missing.join(', ')}`);
  }
}

export default config;
