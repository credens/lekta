import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import config from '../config.js';
import pool from '../db.js';
import auth from '../middleware/auth.js';

const router = Router();

function signToken(userId) {
  return jwt.sign({ sub: userId }, config.jwtSecret, { expiresIn: config.jwtExpiresIn });
}

// POST /auth/register
router.post('/register', async (req, res) => {
  const { email, password, business_name, phone } = req.body;

  if (!email?.trim() || !password || !business_name?.trim()) {
    return res.status(400).json({ error: 'Email, contraseña y nombre del negocio son requeridos' });
  }
  if (password.length < 6) {
    return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
  }

  try {
    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email.trim().toLowerCase()]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Ya existe una cuenta con ese email' });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const { rows } = await pool.query(
      `INSERT INTO users (email, password_hash, business_name, phone)
       VALUES ($1, $2, $3, $4)
       RETURNING id, email, business_name, phone, subscription_tier, created_at`,
      [email.trim().toLowerCase(), passwordHash, business_name.trim(), phone?.trim() || null]
    );

    const user = rows[0];
    const token = signToken(user.id);

    res.status(201).json({ token, user });
  } catch (err) {
    console.error('Register error:', err.message);
    res.status(500).json({ error: 'Error al crear la cuenta' });
  }
});

// POST /auth/login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email y contraseña requeridos' });
  }

  try {
    const { rows } = await pool.query(
      'SELECT id, email, password_hash, business_name, subscription_tier, is_active FROM users WHERE email = $1',
      [email.trim().toLowerCase()]
    );

    if (!rows[0] || !rows[0].is_active) {
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    const valid = await bcrypt.compare(password, rows[0].password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    const { password_hash, ...user } = rows[0];
    const token = signToken(user.id);

    res.json({ token, user });
  } catch (err) {
    console.error('Login error:', err.message);
    res.status(500).json({ error: 'Error al iniciar sesión' });
  }
});

// GET /auth/me
router.get('/me', auth, (req, res) => {
  res.json({ user: req.user });
});

// PUT /auth/me
router.put('/me', auth, async (req, res) => {
  const { business_name, phone } = req.body;

  try {
    const { rows } = await pool.query(
      `UPDATE users SET
        business_name = COALESCE($1, business_name),
        phone = COALESCE($2, phone),
        updated_at = now()
       WHERE id = $3
       RETURNING id, email, business_name, phone, subscription_tier`,
      [business_name?.trim() || null, phone?.trim() || null, req.user.id]
    );
    res.json({ user: rows[0] });
  } catch (err) {
    console.error('Update profile error:', err.message);
    res.status(500).json({ error: 'Error al actualizar perfil' });
  }
});

// PUT /auth/password
router.put('/password', auth, async (req, res) => {
  const { current_password, new_password } = req.body;

  if (!current_password || !new_password) {
    return res.status(400).json({ error: 'Contraseña actual y nueva requeridas' });
  }
  if (new_password.length < 6) {
    return res.status(400).json({ error: 'La nueva contraseña debe tener al menos 6 caracteres' });
  }

  try {
    const { rows } = await pool.query('SELECT password_hash FROM users WHERE id = $1', [req.user.id]);
    const valid = await bcrypt.compare(current_password, rows[0].password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Contraseña actual incorrecta' });
    }

    const hash = await bcrypt.hash(new_password, 12);
    await pool.query('UPDATE users SET password_hash = $1, updated_at = now() WHERE id = $2', [hash, req.user.id]);

    res.json({ message: 'Contraseña actualizada' });
  } catch (err) {
    console.error('Change password error:', err.message);
    res.status(500).json({ error: 'Error al cambiar contraseña' });
  }
});

export default router;
