const SECRET_KEY_PATTERN = /(authorization|access_token|refresh_token|client_secret|token|secret|password|code_verifier)/i;

export function sanitizeForLog(value, depth = 0) {
  if (value == null) return value;
  if (depth > 6) return '[MaxDepth]';
  if (Array.isArray(value)) return value.map(item => sanitizeForLog(item, depth + 1));
  if (typeof value !== 'object') return value;

  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [
      key,
      SECRET_KEY_PATTERN.test(key) ? '[REDACTED]' : sanitizeForLog(item, depth + 1),
    ])
  );
}
