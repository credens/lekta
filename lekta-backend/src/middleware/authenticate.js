import pool from '../db.js';
import { verifyAccessToken } from '../lib/authTokens.js';
import HttpError from '../lib/httpError.js';

export default async function authenticate(req, _res, next) {
  try {
    const header = req.get('authorization') || '';
    const match = header.match(/^Bearer\s+(.+)$/i);
    if (!match) throw new HttpError(401, 'Authorization bearer token is required');

    const payload = verifyAccessToken(match[1]);
    if (!payload.business_id || !payload.session_id) {
      throw new HttpError(401, 'Invalid bearer token');
    }

    const { rows } = await pool.query(
      `SELECT id
       FROM app_sessions
       WHERE id = $1
         AND business_id = $2
         AND revoked_at IS NULL
         AND expires_at > now()`,
      [payload.session_id, payload.business_id]
    );
    if (!rows[0]) throw new HttpError(401, 'Session revoked or expired');

    req.auth = {
      businessId: String(payload.business_id),
      sessionId: String(payload.session_id),
      deviceId: payload.device_id ? String(payload.device_id) : null,
      operatorId: payload.operator_id ? String(payload.operator_id) : null,
    };
    next();
  } catch (err) {
    next(err);
  }
}
