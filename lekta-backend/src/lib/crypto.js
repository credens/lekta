import crypto from 'crypto';
import config, { requireConfig } from '../config.js';

function base64Url(buffer) {
  return Buffer.from(buffer).toString('base64url');
}

function readEncryptionKey() {
  requireConfig(['tokenEncryptionKey']);
  const value = config.tokenEncryptionKey.trim();

  if (/^[a-f0-9]{64}$/i.test(value)) {
    return Buffer.from(value, 'hex');
  }

  const decoded = Buffer.from(value, 'base64');
  if (decoded.length === 32) {
    return decoded;
  }

  return crypto.createHash('sha256').update(value).digest();
}

export function encryptSecret(plainText) {
  if (plainText == null || plainText === '') return null;
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', readEncryptionKey(), iv);
  const encrypted = Buffer.concat([cipher.update(String(plainText), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return ['v1', base64Url(iv), base64Url(tag), base64Url(encrypted)].join(':');
}

export function decryptSecret(encryptedValue) {
  if (!encryptedValue) return null;
  const [version, iv, tag, encrypted] = String(encryptedValue).split(':');
  if (version !== 'v1' || !iv || !tag || !encrypted) {
    throw new Error('Unsupported encrypted secret format');
  }

  const decipher = crypto.createDecipheriv(
    'aes-256-gcm',
    readEncryptionKey(),
    Buffer.from(iv, 'base64url')
  );
  decipher.setAuthTag(Buffer.from(tag, 'base64url'));
  return Buffer.concat([
    decipher.update(Buffer.from(encrypted, 'base64url')),
    decipher.final(),
  ]).toString('utf8');
}

export function hashSecret(secret) {
  return crypto.createHash('sha256').update(String(secret)).digest('hex');
}

export function randomToken(bytes = 32) {
  return crypto.randomBytes(bytes).toString('base64url');
}

export function timingSafeEqualString(a, b) {
  const left = Buffer.from(String(a || ''));
  const right = Buffer.from(String(b || ''));
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}
