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
};

export function requireConfig(keys) {
  const missing = keys.filter(key => !config[key]);
  if (missing.length) {
    throw new Error(`Missing required config: ${missing.join(', ')}`);
  }
}

export default config;
