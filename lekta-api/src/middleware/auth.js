import jwt from 'jsonwebtoken';
import config from '../config.js';
import pool from '../db.js';

export default async function auth(req, res, next) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Token requerido' });
  }

  try {
    const payload = jwt.verify(header.slice(7), config.jwtSecret);
    const { rows } = await pool.query(
      'SELECT id, email, business_name, subscription_tier, is_active FROM users WHERE id = $1',
      [payload.sub]
    );
    if (!rows[0] || !rows[0].is_active) {
      return res.status(401).json({ error: 'Usuario no válido' });
    }
    req.user = rows[0];
    next();
  } catch {
    return res.status(401).json({ error: 'Token inválido' });
  }
}
