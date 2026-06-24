import { Router } from 'express';
import pool from '../db.js';
import { exchangeOAuthCode, oauthExpiresAt } from '../lib/mercadoPago.js';
import HttpError from '../lib/httpError.js';

const router = Router();

router.post('/oauth/exchange', async (req, res, next) => {
  try {
    const { code, code_verifier, redirect_uri } = req.body;
    if (!code?.trim()) throw new HttpError(400, 'code is required');

    const token = await exchangeOAuthCode({
      code: code.trim(),
      codeVerifier: code_verifier,
      redirectUri: redirect_uri,
    });

    if (!token.access_token || !token.user_id) {
      throw new HttpError(502, 'Mercado Pago OAuth response is missing required fields', token);
    }

    const scopes = token.scope ? String(token.scope).split(/\s+/).filter(Boolean) : [];
    const expiresAt = oauthExpiresAt(token.expires_in);

    const { rows } = await pool.query(
      `INSERT INTO mercado_pago_accounts
        (mp_user_id, access_token, refresh_token, expires_at, scopes)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (mp_user_id) DO UPDATE SET
        access_token = EXCLUDED.access_token,
        refresh_token = EXCLUDED.refresh_token,
        expires_at = EXCLUDED.expires_at,
        scopes = EXCLUDED.scopes
       RETURNING id, mp_user_id, expires_at, scopes, created_at, updated_at`,
      [
        String(token.user_id),
        token.access_token,
        token.refresh_token || null,
        expiresAt,
        scopes,
      ]
    );

    res.json({
      mp_account_id: rows[0].id,
      mp_user_id: rows[0].mp_user_id,
      expires_at: rows[0].expires_at,
      scopes: rows[0].scopes,
    });
  } catch (err) {
    next(err);
  }
});

export default router;
