import { Router } from 'express';
import auth from '../middleware/auth.js';
import pool from '../db.js';

const router = Router();
router.use(auth);

const DEVICE_LIMIT = 1;

// GET /devices
router.get('/', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, device_name, platform, last_active, created_at FROM devices WHERE user_id = $1 ORDER BY last_active DESC',
      [req.user.id]
    );
    const limit = DEVICE_LIMIT;
    res.json({ devices: rows, limit });
  } catch (err) {
    console.error('List devices error:', err.message);
    res.status(500).json({ error: 'Error al listar dispositivos' });
  }
});

// POST /devices
router.post('/', async (req, res) => {
  const { device_name, platform } = req.body;

  if (!platform || !['ios', 'android'].includes(platform)) {
    return res.status(400).json({ error: 'Plataforma debe ser ios o android' });
  }

  try {
    const { rows: existing } = await pool.query(
      'SELECT COUNT(*) as count FROM devices WHERE user_id = $1',
      [req.user.id]
    );
    const limit = DEVICE_LIMIT;
    if (parseInt(existing[0].count) >= limit) {
      return res.status(403).json({
        error: `El uso gratuito permite hasta ${limit} dispositivo${limit > 1 ? 's' : ''}.`
      });
    }

    const { rows } = await pool.query(
      `INSERT INTO devices (user_id, device_name, platform)
       VALUES ($1, $2, $3)
       RETURNING id, device_name, platform, last_active, created_at`,
      [req.user.id, device_name?.trim() || null, platform]
    );
    res.status(201).json({ device: rows[0] });
  } catch (err) {
    console.error('Register device error:', err.message);
    res.status(500).json({ error: 'Error al registrar dispositivo' });
  }
});

// PUT /devices/:id/heartbeat
router.put('/:id/heartbeat', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `UPDATE devices SET last_active = now()
       WHERE id = $1 AND user_id = $2
       RETURNING id, device_name, platform, last_active`,
      [req.params.id, req.user.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Dispositivo no encontrado' });
    res.json({ device: rows[0] });
  } catch (err) {
    console.error('Heartbeat error:', err.message);
    res.status(500).json({ error: 'Error al actualizar dispositivo' });
  }
});

// DELETE /devices/:id
router.delete('/:id', async (req, res) => {
  try {
    const { rowCount } = await pool.query(
      'DELETE FROM devices WHERE id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (rowCount === 0) return res.status(404).json({ error: 'Dispositivo no encontrado' });
    res.json({ message: 'Dispositivo eliminado' });
  } catch (err) {
    console.error('Delete device error:', err.message);
    res.status(500).json({ error: 'Error al eliminar dispositivo' });
  }
});

export default router;
