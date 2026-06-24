import { Router } from 'express';
import auth from '../middleware/auth.js';
import pool from '../db.js';

const router = Router();
router.use(auth);

// GET /caja/status
router.get('/status', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT cs.*, o.name as operator_name
       FROM caja_sessions cs
       LEFT JOIN operators o ON o.id = cs.operator_id
       WHERE cs.user_id = $1 AND cs.closed_at IS NULL
       ORDER BY cs.opened_at DESC LIMIT 1`,
      [req.user.id]
    );
    res.json({ session: rows[0] || null });
  } catch (err) {
    console.error('Caja status error:', err.message);
    res.status(500).json({ error: 'Error al consultar estado de caja' });
  }
});

// POST /caja/open
router.post('/open', async (req, res) => {
  const { operator_id, device_id } = req.body;

  try {
    const { rows: open } = await pool.query(
      'SELECT id FROM caja_sessions WHERE user_id = $1 AND closed_at IS NULL',
      [req.user.id]
    );
    if (open.length > 0) {
      return res.status(409).json({ error: 'Ya hay una caja abierta' });
    }

    const { rows } = await pool.query(
      `INSERT INTO caja_sessions (user_id, operator_id, device_id)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [req.user.id, operator_id || null, device_id || null]
    );
    res.status(201).json({ session: rows[0] });
  } catch (err) {
    console.error('Open caja error:', err.message);
    res.status(500).json({ error: 'Error al abrir caja' });
  }
});

// POST /caja/sale
router.post('/sale', async (req, res) => {
  const { total, payment_method, items } = req.body;

  if (!total || total <= 0) return res.status(400).json({ error: 'Total inválido' });
  if (!['qr_mp', 'point_mp', 'cash'].includes(payment_method)) {
    return res.status(400).json({ error: 'Método de pago inválido' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const { rows: sessions } = await client.query(
      'SELECT id FROM caja_sessions WHERE user_id = $1 AND closed_at IS NULL',
      [req.user.id]
    );
    if (!sessions[0]) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'No hay caja abierta' });
    }

    const sessionId = sessions[0].id;
    const isMP = payment_method === 'qr_mp' || payment_method === 'point_mp';

    await client.query(
      `UPDATE caja_sessions SET
        total_ventas = total_ventas + $1,
        total_mp = total_mp + $2,
        total_efectivo = total_efectivo + $3,
        cantidad_ventas = cantidad_ventas + 1
       WHERE id = $4`,
      [total, isMP ? total : 0, isMP ? 0 : total, sessionId]
    );

    const { rows } = await client.query(
      `INSERT INTO sales (caja_session_id, user_id, total, payment_method, items)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, total, payment_method, created_at`,
      [sessionId, req.user.id, total, payment_method, JSON.stringify(items || [])]
    );

    if (items?.length) {
      for (const item of items) {
        if (item.product_id && item.quantity > 0) {
          await client.query(
            `UPDATE products SET stock = GREATEST(0, stock - $1), updated_at = now()
             WHERE id = $2 AND user_id = $3`,
            [item.quantity, item.product_id, req.user.id]
          );
        }
      }
    }

    await client.query('COMMIT');
    res.status(201).json({ sale: rows[0] });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Sale error:', err.message);
    res.status(500).json({ error: 'Error al registrar venta' });
  } finally {
    client.release();
  }
});

// POST /caja/close
router.post('/close', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `UPDATE caja_sessions SET closed_at = now()
       WHERE user_id = $1 AND closed_at IS NULL
       RETURNING *`,
      [req.user.id]
    );
    if (!rows[0]) return res.status(400).json({ error: 'No hay caja abierta' });

    const session = rows[0];
    const { rows: opRows } = await pool.query(
      'SELECT name FROM operators WHERE id = $1',
      [session.operator_id]
    );

    res.json({
      resumen: {
        ...session,
        operator_name: opRows[0]?.name || null,
      }
    });
  } catch (err) {
    console.error('Close caja error:', err.message);
    res.status(500).json({ error: 'Error al cerrar caja' });
  }
});

// GET /caja/history
router.get('/history', async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 30, 100);
  const offset = parseInt(req.query.offset) || 0;

  try {
    const { rows } = await pool.query(
      `SELECT cs.*, o.name as operator_name
       FROM caja_sessions cs
       LEFT JOIN operators o ON o.id = cs.operator_id
       WHERE cs.user_id = $1 AND cs.closed_at IS NOT NULL
       ORDER BY cs.closed_at DESC
       LIMIT $2 OFFSET $3`,
      [req.user.id, limit, offset]
    );
    res.json({ sessions: rows });
  } catch (err) {
    console.error('Caja history error:', err.message);
    res.status(500).json({ error: 'Error al obtener historial' });
  }
});

// GET /caja/sales
router.get('/sales', async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 50, 200);
  const { from, to } = req.query;

  try {
    let query = 'SELECT * FROM sales WHERE user_id = $1';
    const params = [req.user.id];
    let i = 2;

    if (from) {
      query += ` AND created_at >= $${i++}`;
      params.push(new Date(from));
    }
    if (to) {
      query += ` AND created_at <= $${i++}`;
      params.push(new Date(to));
    }

    query += ` ORDER BY created_at DESC LIMIT $${i}`;
    params.push(limit);

    const { rows } = await pool.query(query, params);
    res.json({ sales: rows });
  } catch (err) {
    console.error('List sales error:', err.message);
    res.status(500).json({ error: 'Error al listar ventas' });
  }
});

export default router;
