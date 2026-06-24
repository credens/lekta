import { Router } from 'express';
import pool from '../db.js';
import { createPreference } from '../lib/mercadoPago.js';
import {
  calculateTotal,
  makeExternalReference,
  makeOrderId,
  normalizeOrderItems,
} from '../lib/orders.js';
import HttpError from '../lib/httpError.js';

const router = Router();

async function getLatestMpAccount(client = pool) {
  const { rows } = await client.query(
    `SELECT id, access_token
     FROM mercado_pago_accounts
     ORDER BY updated_at DESC
     LIMIT 1`
  );
  return rows[0] || null;
}

router.post('/orders', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const items = normalizeOrderItems(req.body.items);
    const operatorId = req.body.operator_id != null ? String(req.body.operator_id).trim() : '';
    const cashSessionId = req.body.cash_session_id != null ? String(req.body.cash_session_id).trim() : '';
    if (!operatorId) throw new HttpError(400, 'operator_id is required');
    if (!cashSessionId) throw new HttpError(400, 'cash_session_id is required');

    const totalAmount = calculateTotal(items);
    const orderId = makeOrderId();
    const externalReference = makeExternalReference(orderId);
    const currency = req.body.currency || 'ARS';
    const latestAccount = req.body.mp_account_id ? null : await getLatestMpAccount(client);
    const mpAccountId = req.body.mp_account_id || latestAccount?.id || null;

    await client.query('BEGIN');

    const { rows: orderRows } = await client.query(
      `INSERT INTO orders
        (id, external_reference, status, total_amount, currency, operator_id, cash_session_id, device_id, mp_account_id)
       VALUES ($1, $2, 'pending', $3, $4, $5, $6, $7, $8)
       RETURNING id, external_reference, status, total_amount, currency, operator_id, cash_session_id, device_id, mp_account_id, created_at`,
      [
        orderId,
        externalReference,
        totalAmount,
        currency,
        operatorId,
        cashSessionId,
        req.body.device_id != null ? String(req.body.device_id).trim() || null : null,
        mpAccountId,
      ]
    );

    const order = orderRows[0];
    for (const item of items) {
      await client.query(
        `INSERT INTO order_items (order_id, barcode, title, unit_price, quantity)
         VALUES ($1, $2, $3, $4, $5)`,
        [order.id, item.barcode, item.title, item.unit_price, item.quantity]
      );
    }

    await client.query('COMMIT');
    res.status(201).json({
      order_id: order.id,
      external_reference: order.external_reference,
      status: order.status,
      total_amount: Number(order.total_amount),
    });
  } catch (err) {
    await client.query('ROLLBACK');
    if (err.message?.startsWith('items')) next(new HttpError(400, err.message));
    else next(err);
  } finally {
    client.release();
  }
});

router.post('/orders/:id/preference', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const { rows: orderRows } = await client.query(
      `SELECT *
       FROM orders
       WHERE id = $1`,
      [req.params.id]
    );
    const order = orderRows[0];
    if (!order) throw new HttpError(404, 'Order not found');
    if (order.status !== 'pending') {
      throw new HttpError(409, `Order is not pending: ${order.status}`);
    }

    const { rows: itemRows } = await client.query(
      `SELECT id, barcode, title, unit_price, quantity
       FROM order_items
       WHERE order_id = $1
       ORDER BY id`,
      [order.id]
    );

    let mpAccount;
    if (order.mp_account_id) {
      const { rows } = await client.query(
        'SELECT id, access_token FROM mercado_pago_accounts WHERE id = $1',
        [order.mp_account_id]
      );
      mpAccount = rows[0];
    } else {
      mpAccount = await getLatestMpAccount(client);
    }

    if (!mpAccount) throw new HttpError(409, 'No Mercado Pago account connected');

    const preference = await createPreference({
      accessToken: mpAccount.access_token,
      order,
      items: itemRows,
      successUrl: req.body.success_url || null,
    });

    await client.query(
      `UPDATE orders
       SET mp_account_id = $2,
           mp_preference_id = $3
       WHERE id = $1`,
      [order.id, mpAccount.id, preference.id]
    );

    res.json({
      order_id: order.id,
      preference_id: preference.id,
      init_point: preference.init_point,
      sandbox_init_point: preference.sandbox_init_point,
    });
  } catch (err) {
    next(err);
  } finally {
    client.release();
  }
});

router.get('/orders/:id/status', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, status, status_detail, mp_payment_id
       FROM orders
       WHERE id = $1`,
      [req.params.id]
    );

    const order = rows[0];
    if (!order) throw new HttpError(404, 'Order not found');
    res.json({
      order_id: order.id,
      status: order.status,
      status_detail: order.status_detail,
      mp_payment_id: order.mp_payment_id,
    });
  } catch (err) {
    next(err);
  }
});

export default router;
