import pool from '../db.js';
import HttpError from './httpError.js';
import { decryptSecret, encryptSecret } from './crypto.js';
import { oauthExpiresAt, refreshOAuthToken } from './mercadoPago.js';

function scopesFromToken(token) {
  return token.scope ? String(token.scope).split(/\s+/).filter(Boolean) : [];
}

function decryptAccount(row) {
  if (!row) return null;
  if (!row.encrypted_access_token) {
    throw new HttpError(409, 'Mercado Pago account must be reconnected to encrypt credentials');
  }

  return {
    id: row.id,
    businessId: row.business_id,
    mpUserId: row.mp_user_id,
    accessToken: decryptSecret(row.encrypted_access_token),
    refreshToken: decryptSecret(row.encrypted_refresh_token),
    expiresAt: row.expires_at,
    scopes: row.scopes || [],
  };
}

export async function saveMercadoPagoAccount({ businessId, token, client = pool }) {
  const scopes = scopesFromToken(token);
  const expiresAt = oauthExpiresAt(token.expires_in);

  const { rows } = await client.query(
    `INSERT INTO mercado_pago_accounts
      (business_id, mp_user_id, encrypted_access_token, encrypted_refresh_token, access_token, refresh_token, expires_at, scopes)
     VALUES ($1, $2, $3, $4, NULL, NULL, $5, $6)
     ON CONFLICT (mp_user_id) DO UPDATE SET
      business_id = EXCLUDED.business_id,
      encrypted_access_token = EXCLUDED.encrypted_access_token,
      encrypted_refresh_token = EXCLUDED.encrypted_refresh_token,
      access_token = NULL,
      refresh_token = NULL,
      expires_at = EXCLUDED.expires_at,
      scopes = EXCLUDED.scopes
     RETURNING id, business_id, mp_user_id, expires_at, scopes, created_at, updated_at`,
    [
      businessId,
      String(token.user_id),
      encryptSecret(token.access_token),
      encryptSecret(token.refresh_token || null),
      expiresAt,
      scopes,
    ]
  );

  return rows[0];
}

export async function getMercadoPagoAccountById({ businessId, accountId, client = pool }) {
  const { rows } = await client.query(
    `SELECT id, business_id, mp_user_id, encrypted_access_token, encrypted_refresh_token, expires_at, scopes
     FROM mercado_pago_accounts
     WHERE id = $1 AND business_id = $2`,
    [accountId, businessId]
  );
  return decryptAccount(rows[0]);
}

export async function getLatestMercadoPagoAccount({ businessId, client = pool }) {
  const { rows } = await client.query(
    `SELECT id, business_id, mp_user_id, encrypted_access_token, encrypted_refresh_token, expires_at, scopes
     FROM mercado_pago_accounts
     WHERE business_id = $1
       AND encrypted_access_token IS NOT NULL
     ORDER BY updated_at DESC
     LIMIT 1`,
    [businessId]
  );
  return decryptAccount(rows[0]);
}

export async function listMercadoPagoAccounts({ client = pool } = {}) {
  const { rows } = await client.query(
    `SELECT id, business_id, mp_user_id, encrypted_access_token, encrypted_refresh_token, expires_at, scopes
     FROM mercado_pago_accounts
     WHERE encrypted_access_token IS NOT NULL
     ORDER BY updated_at DESC`
  );
  return rows.map(decryptAccount);
}

export async function refreshMercadoPagoAccountIfNeeded(account, { client = pool } = {}) {
  if (!account) return null;
  const expiresAt = account.expiresAt ? new Date(account.expiresAt).getTime() : 0;
  const refreshWindowMs = 2 * 60 * 1000;
  if (expiresAt && expiresAt - Date.now() > refreshWindowMs) return account;
  if (!account.refreshToken) throw new HttpError(409, 'Mercado Pago account has no refresh token; reconnect account');

  const token = await refreshOAuthToken({ refreshToken: account.refreshToken });
  const accessToken = token.access_token;
  const refreshToken = token.refresh_token || account.refreshToken;
  const expires = oauthExpiresAt(token.expires_in);
  const scopes = token.scope ? scopesFromToken(token) : account.scopes;

  const { rows } = await client.query(
    `UPDATE mercado_pago_accounts
     SET encrypted_access_token = $2,
         encrypted_refresh_token = $3,
         access_token = NULL,
         refresh_token = NULL,
         expires_at = $4,
         scopes = $5
     WHERE id = $1
     RETURNING id, business_id, mp_user_id, encrypted_access_token, encrypted_refresh_token, expires_at, scopes`,
    [account.id, encryptSecret(accessToken), encryptSecret(refreshToken), expires, scopes]
  );

  return decryptAccount(rows[0]);
}
