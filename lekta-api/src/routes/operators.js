import { Router } from 'express';
import crypto from 'crypto';
import auth from '../middleware/auth.js';
import pool from '../db.js';

const router = Router();
router.use(auth);

function hashPIN(pin) {
  return crypto.createHash('sha256').update(pin, 'utf8').digest('hex');
}

// GET /operators
router.get('/', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, name, is_active, created_at FROM operators WHERE user_id = $1 ORDER BY created_at',
      [req.user.id]
    );
    res.json({ operators: rows });
  } catch (err) {
    console.error('List operators error:', err.message);
    res.status(500).json({ error: 'Error al listar operadores' });
  }
});

// POST /operators
router.post('/', async (req, res) => {
  const { name, pin } = req.body;

  if (!name?.trim()) {
    return res.status(400).json({ error: 'Nombre requerido' });
  }
  if (!pin || pin.length !== 4 || !/^\d{4}$/.test(pin)) {
    return res.status(400).json({ error: 'PIN debe ser de 4 dígitos' });
  }

  try {
    const { rows } = await pool.query(
      `INSERT INTO operators (user_id, name, pin_hash)
       VALUES ($1, $2, $3)
       RETURNING id, name, is_active, created_at`,
      [req.user.id, name.trim(), hashPIN(pin)]
    );
    res.status(201).json({ operator: rows[0] });
  } catch (err) {
    console.error('Create operator error:', err.message);
    res.status(500).json({ error: 'Error al crear operador' });
  }
});

// PUT /operators/:id
router.put('/:id', async (req, res) => {
  const { name, pin, is_active } = req.body;

  try {
    const updates = [];
    const values = [];
    let i = 1;

    if (name?.trim()) {
      updates.push(`name = $${i++}`);
      values.push(name.trim());
    }
    if (pin) {
      if (pin.length !== 4 || !/^\d{4}$/.test(pin)) {
        return res.status(400).json({ error: 'PIN debe ser de 4 dígitos' });
      }
      updates.push(`pin_hash = $${i++}`);
      values.push(hashPIN(pin));
    }
    if (typeof is_active === 'boolean') {
      updates.push(`is_active = $${i++}`);
      values.push(is_active);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'Nada que actualizar' });
    }

    values.push(req.params.id, req.user.id);
    const { rows } = await pool.query(
      `UPDATE operators SET ${updates.join(', ')}
       WHERE id = $${i++} AND user_id = $${i}
       RETURNING id, name, is_active, created_at`,
      values
    );

    if (!rows[0]) return res.status(404).json({ error: 'Operador no encontrado' });
    res.json({ operator: rows[0] });
  } catch (err) {
    console.error('Update operator error:', err.message);
    res.status(500).json({ error: 'Error al actualizar operador' });
  }
});

// DELETE /operators/:id
router.delete('/:id', async (req, res) => {
  try {
    const { rowCount } = await pool.query(
      'DELETE FROM operators WHERE id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (rowCount === 0) return res.status(404).json({ error: 'Operador no encontrado' });
    res.json({ message: 'Operador eliminado' });
  } catch (err) {
    console.error('Delete operator error:', err.message);
    res.status(500).json({ error: 'Error al eliminar operador' });
  }
});

// POST /operators/:id/verify-pin
router.post('/:id/verify-pin', async (req, res) => {
  const { pin } = req.body;
  if (!pin) return res.status(400).json({ error: 'PIN requerido' });

  try {
    const { rows } = await pool.query(
      'SELECT id, name, pin_hash, is_active FROM operators WHERE id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );

    if (!rows[0]) return res.status(404).json({ error: 'Operador no encontrado' });
    if (!rows[0].is_active) return res.status(403).json({ error: 'Operador desactivado' });

    const valid = rows[0].pin_hash === hashPIN(pin);
    res.json({ valid, operator: valid ? { id: rows[0].id, name: rows[0].name } : null });
  } catch (err) {
    console.error('Verify PIN error:', err.message);
    res.status(500).json({ error: 'Error al verificar PIN' });
  }
});

export default router;
