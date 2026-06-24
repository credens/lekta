import HttpError from '../lib/httpError.js';

export default function rateLimit({ windowMs, max }) {
  const buckets = new Map();

  return (req, _res, next) => {
    const now = Date.now();
    const key = `${req.ip}:${req.path}`;
    const bucket = buckets.get(key);

    if (!bucket || bucket.resetAt <= now) {
      buckets.set(key, { count: 1, resetAt: now + windowMs });
      return next();
    }

    bucket.count += 1;
    if (bucket.count > max) {
      return next(new HttpError(429, 'Too many requests'));
    }

    return next();
  };
}
