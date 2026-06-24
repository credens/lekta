import { randomUUID } from 'crypto';
import { Router } from 'express';
import config, { requireConfig } from '../config.js';
import pool from '../db.js';
import { refreshExpiresAt, signAccessToken } from '../lib/authTokens.js';
import { hashSecret, randomToken, timingSafeEqualString } from '../lib/crypto.js';
import HttpError from '../lib/httpError.js';

const router = Router();

function normalizeBusinessId(value) {
  const businessId = value == null ? 'default' : String(value).trim();
  if (!/^[a-zA-Z0-9_-]{1,80}$/.test(businessId)) {
    throw new HttpError(400, 'business_id is invalid');
  }
  return businessId;
}

function optionalString(value, max = 160) {
  if (value == null) return null;
  const text = String(value).trim();
  if (!text) return null;
  if (text.length > max) throw new HttpError(400, 'Field is too long');
  return text;
}

function assertBootstrapToken(req) {
  requireConfig(['appBootstrapToken']);
  const provided = req.get('x-bootstrap-token') || req.body.bootstrap_token;
  if (!timingSafeEqualString(provided, config.appBootstrapToken)) {
    throw new HttpError(401, 'Invalid bootstrap token');
  }
}

async function createSession({ businessId, deviceId, operatorId, client = pool }) {
  const sessionId = randomUUID();
  const refreshToken = randomToken(48);
  const refreshTokenHash = hashSecret(refreshToken);
  const refreshTokenExpiresAt = refreshExpiresAt();

  await client.query(
    `INSERT INTO app_sessions (id, business_id, device_id, operator_id, refresh_token_hash, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [sessionId, businessId, deviceId, operatorId, refreshTokenHash, refreshTokenExpiresAt]
  );

  const access = signAccessToken({
    session_id: sessionId,
    business_id: businessId,
    device_id: deviceId,
    operator_id: operatorId,
  });

  return {
    access_token: access.token,
    access_token_expires_at: access.expiresAt,
    refresh_token: refreshToken,
    refresh_token_expires_at: refreshTokenExpiresAt,
    business_id: businessId,
  };
}

router.post('/session', async (req, res, next) => {
  const client = await pool.connect();
  try {
    assertBootstrapToken(req);
    const businessId = normalizeBusinessId(req.body.business_id);
    const deviceId = optionalString(req.body.device_id);
    const operatorId = optionalString(req.body.operator_id);

    await client.query('BEGIN');
    await client.query(
      `INSERT INTO businesses (id, name)
       VALUES ($1, $1)
       ON CONFLICT (id) DO NOTHING`,
      [businessId]
    );
    const session = await createSession({ businessId, deviceId, operatorId, client });
    await client.query('COMMIT');

    res.status(201).json(session);
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

router.post('/refresh', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const refreshToken = optionalString(req.body.refresh_token, 512);
    if (!refreshToken) throw new HttpError(400, 'refresh_token is required');
    const refreshTokenHash = hashSecret(refreshToken);

    await client.query('BEGIN');
    const { rows } = await client.query(
      `SELECT id, business_id, device_id, operator_id
       FROM app_sessions
       WHERE refresh_token_hash = $1
         AND revoked_at IS NULL
         AND expires_at > now()
       FOR UPDATE`,
      [refreshTokenHash]
    );

    const existing = rows[0];
    if (!existing) throw new HttpError(401, 'Invalid refresh token');

    await client.query(
      `UPDATE app_sessions
       SET revoked_at = now()
       WHERE id = $1`,
      [existing.id]
    );

    const session = await createSession({
      businessId: existing.business_id,
      deviceId: existing.device_id,
      operatorId: existing.operator_id,
      client,
    });
    await client.query('COMMIT');

    res.json(session);
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

router.post('/revoke', async (req, res, next) => {
  try {
    const refreshToken = optionalString(req.body.refresh_token, 512);
    if (!refreshToken) throw new HttpError(400, 'refresh_token is required');

    await pool.query(
      `UPDATE app_sessions
       SET revoked_at = now()
       WHERE refresh_token_hash = $1
         AND revoked_at IS NULL`,
      [hashSecret(refreshToken)]
    );

    res.json({ revoked: true });
  } catch (err) {
    next(err);
  }
});

export default router;
