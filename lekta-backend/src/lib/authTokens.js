import crypto from 'crypto';
import config, { requireConfig } from '../config.js';
import HttpError from './httpError.js';

function base64UrlJson(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function sign(input) {
  requireConfig(['jwtSecret']);
  return crypto.createHmac('sha256', config.jwtSecret).update(input).digest('base64url');
}

export function signAccessToken(payload, expiresInSeconds = config.appAccessTokenSeconds) {
  const now = Math.floor(Date.now() / 1000);
  const exp = now + Number(expiresInSeconds);
  const header = { alg: 'HS256', typ: 'JWT' };
  const body = { ...payload, iat: now, exp };
  const unsigned = `${base64UrlJson(header)}.${base64UrlJson(body)}`;
  return {
    token: `${unsigned}.${sign(unsigned)}`,
    expiresAt: new Date(exp * 1000),
  };
}

export function verifyAccessToken(token) {
  if (!token || typeof token !== 'string') {
    throw new HttpError(401, 'Missing bearer token');
  }

  const parts = token.split('.');
  if (parts.length !== 3) throw new HttpError(401, 'Invalid bearer token');

  const unsigned = `${parts[0]}.${parts[1]}`;
  const expected = sign(unsigned);
  const actual = parts[2];
  const expectedBuffer = Buffer.from(expected);
  const actualBuffer = Buffer.from(actual);

  if (expectedBuffer.length !== actualBuffer.length || !crypto.timingSafeEqual(expectedBuffer, actualBuffer)) {
    throw new HttpError(401, 'Invalid bearer token');
  }

  let payload;
  try {
    payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch {
    throw new HttpError(401, 'Invalid bearer token');
  }

  if (!payload.exp || payload.exp <= Math.floor(Date.now() / 1000)) {
    throw new HttpError(401, 'Bearer token expired');
  }

  return payload;
}

export function refreshExpiresAt() {
  return new Date(Date.now() + Number(config.appRefreshTokenDays) * 24 * 60 * 60 * 1000);
}
