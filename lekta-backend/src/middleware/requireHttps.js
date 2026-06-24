import config from '../config.js';
import HttpError from '../lib/httpError.js';

export default function requireHttps(req, _res, next) {
  if (!config.enforceHttps || req.path === '/health') return next();
  const forwardedProto = req.get('x-forwarded-proto');
  if (req.secure || forwardedProto === 'https') return next();
  return next(new HttpError(403, 'HTTPS is required'));
}
