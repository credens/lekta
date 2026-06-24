import { Router } from 'express';
import auth from '../middleware/auth.js';
import pool from '../db.js';

const router = Router();
router.use(auth);

const FREE_PRODUCT_LIMIT = 250;

// GET /products
router.get('/', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, barcode, name, price, stock, discount, category, variants, is_active, created_at, updated_at
       FROM products WHERE user_id = $1 AND is_active = true
       ORDER BY name`,
      [req.user.id]
    );
    const limit = FREE_PRODUCT_LIMIT;
    res.json({ products: rows, limit, count: rows.length });
  } catch (err) {
    console.error('List products error:', err.message);
    res.status(500).json({ error: 'Error al listar productos' });
  }
});

// GET /products/:id
router.get('/:id', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM products WHERE id = $1 AND user_id = $2',
      [req.params.id, req.user.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Producto no encontrado' });
    res.json({ product: rows[0] });
  } catch (err) {
    console.error('Get product error:', err.message);
    res.status(500).json({ error: 'Error al obtener producto' });
  }
});

// POST /products
router.post('/', async (req, res) => {
  const { barcode, name, price, stock, discount, category, variants } = req.body;

  if (!name?.trim()) return res.status(400).json({ error: 'Nombre requerido' });

  try {
    const { rows: countRows } = await pool.query(
      'SELECT COUNT(*) as count FROM products WHERE user_id = $1 AND is_active = true',
      [req.user.id]
    );
    const limit = FREE_PRODUCT_LIMIT;
    if (parseInt(countRows[0].count) >= limit) {
      return res.status(403).json({ error: `El uso gratuito permite hasta ${limit} productos.` });
    }

    const { rows } = await pool.query(
      `INSERT INTO products (user_id, barcode, name, price, stock, discount, category, variants)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        req.user.id,
        barcode?.trim() || null,
        name.trim(),
        Math.min(Math.max(parseFloat(price) || 0, 0), 9999999),
        Math.min(Math.max(parseInt(stock) || 0, 0), 99999),
        Math.min(Math.max(parseFloat(discount) || 0, 0), 1),
        category?.trim() || '',
        JSON.stringify(variants || []),
      ]
    );
    res.status(201).json({ product: rows[0] });
  } catch (err) {
    console.error('Create product error:', err.message);
    res.status(500).json({ error: 'Error al crear producto' });
  }
});

// PUT /products/:id
router.put('/:id', async (req, res) => {
  const { barcode, name, price, stock, discount, category, variants } = req.body;

  try {
    const { rows } = await pool.query(
      `UPDATE products SET
        barcode = COALESCE($1, barcode),
        name = COALESCE($2, name),
        price = COALESCE($3, price),
        stock = COALESCE($4, stock),
        discount = COALESCE($5, discount),
        category = COALESCE($6, category),
        variants = COALESCE($7, variants),
        updated_at = now()
       WHERE id = $8 AND user_id = $9
       RETURNING *`,
      [
        barcode?.trim(),
        name?.trim(),
        price != null ? Math.min(Math.max(parseFloat(price), 0), 9999999) : null,
        stock != null ? Math.min(Math.max(parseInt(stock), 0), 99999) : null,
        discount != null ? Math.min(Math.max(parseFloat(discount), 0), 1) : null,
        category?.trim(),
        variants ? JSON.stringify(variants) : null,
        req.params.id,
        req.user.id,
      ]
    );

    if (!rows[0]) return res.status(404).json({ error: 'Producto no encontrado' });
    res.json({ product: rows[0] });
  } catch (err) {
    console.error('Update product error:', err.message);
    res.status(500).json({ error: 'Error al actualizar producto' });
  }
});

// PUT /products/:id/stock
router.put('/:id/stock', async (req, res) => {
  const { delta } = req.body;
  if (typeof delta !== 'number') return res.status(400).json({ error: 'delta requerido' });

  try {
    const { rows } = await pool.query(
      `UPDATE products SET
        stock = GREATEST(0, LEAST(99999, stock + $1)),
        updated_at = now()
       WHERE id = $2 AND user_id = $3
       RETURNING id, name, stock`,
      [delta, req.params.id, req.user.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Producto no encontrado' });
    res.json({ product: rows[0] });
  } catch (err) {
    console.error('Update stock error:', err.message);
    res.status(500).json({ error: 'Error al actualizar stock' });
  }
});

// DELETE /products/:id (soft delete)
router.delete('/:id', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `UPDATE products SET is_active = false, updated_at = now()
       WHERE id = $1 AND user_id = $2
       RETURNING id`,
      [req.params.id, req.user.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Producto no encontrado' });
    res.json({ message: 'Producto eliminado' });
  } catch (err) {
    console.error('Delete product error:', err.message);
    res.status(500).json({ error: 'Error al eliminar producto' });
  }
});

export default router;
