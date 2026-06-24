import { Router } from 'express';
import pool from '../db.js';
import { createPreference } from '../lib/mercadoPago.js';
import { getLatestMercadoPagoAccount, getMercadoPagoAccountById, refreshMercadoPagoAccountIfNeeded } from '../lib/mpAccounts.js';
import {
  calculateTotal,
  makeExternalReference,
  makeOrderId,
  normalizeOrderItems,
} from '../lib/orders.js';
import HttpError from '../lib/httpError.js';

const router = Router();

function optionalString(value, max = 160) {
  if (value == null) return null;
  const text = String(value).trim();
  if (!text) return null;
  if (text.length > max) throw new HttpError(400, 'Field is too long');
  return text;
}

function requiredString(value, field, max = 160) {
  const text = optionalString(value, max);
  if (!text) throw new HttpError(400, `${field} is required`);
  return text;
}

function normalizeCurrency(value) {
  const currency = value == null ? 'ARS' : String(value).trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(currency)) throw new HttpError(400, 'currency is invalid');
  return currency;
}

function validateSuccessUrl(value) {
  if (value == null || value === '') return null;
  const text = String(value).trim();
  try {
    const url = new URL(text);
    if (url.protocol !== 'https:') throw new Error('not https');
    return url.toString();
  } catch {
    throw new HttpError(400, 'success_url must be null or a valid HTTPS URL');
  }
}

async function getOrderItems(client, orderId) {
  const { rows } = await client.query(
    `SELECT id, barcode, title, unit_price, quantity
     FROM order_items
     WHERE order_id = $1
     ORDER BY id`,
    [orderId]
  );
  return rows;
}

router.post('/orders', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const items = normalizeOrderItems(req.body.items);
    const operatorId = requiredString(req.body.operator_id, 'operator_id');
    const cashSessionId = requiredString(req.body.cash_session_id, 'cash_session_id');
    const deviceId = optionalString(req.body.device_id);
    const currency = normalizeCurrency(req.body.currency);
    const businessId = req.auth.businessId;

    const totalAmount = calculateTotal(items);
    const orderId = makeOrderId();
    const externalReference = makeExternalReference(orderId);
    const requestedMpAccountId = optionalString(req.body.mp_account_id, 80);
    const latestAccount = requestedMpAccountId ? null : await getLatestMercadoPagoAccount({ businessId, client });
    const mpAccountId = requestedMpAccountId || latestAccount?.id || null;

    if (requestedMpAccountId) {
      const account = await getMercadoPagoAccountById({ businessId, accountId: requestedMpAccountId, client });
      if (!account) throw new HttpError(404, 'Mercado Pago account not found');
    }

    await client.query('BEGIN');

    const { rows: orderRows } = await client.query(
      `INSERT INTO orders
        (id, external_reference, business_id, status, total_amount, currency, operator_id, cash_session_id, device_id, mp_account_id)
       VALUES ($1, $2, $3, 'pending', $4, $5, $6, $7, $8, $9)
       RETURNING id, external_reference, status, total_amount, currency, operator_id, cash_session_id, device_id, mp_account_id, created_at`,
      [
        orderId,
        externalReference,
        businessId,
        totalAmount,
        currency,
        operatorId,
        cashSessionId,
        deviceId,
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
    const businessId = req.auth.businessId;
    const successUrl = validateSuccessUrl(req.body.success_url);
    const { rows: orderRows } = await client.query(
      `SELECT *
       FROM orders
       WHERE id = $1 AND business_id = $2`,
      [req.params.id, businessId]
    );
    const order = orderRows[0];
    if (!order) throw new HttpError(404, 'Order not found');
    if (order.status !== 'pending') {
      throw new HttpError(409, `Order is not pending: ${order.status}`);
    }

    const itemRows = await getOrderItems(client, order.id);
    let mpAccount = order.mp_account_id
      ? await getMercadoPagoAccountById({ businessId, accountId: order.mp_account_id, client })
      : await getLatestMercadoPagoAccount({ businessId, client });

    if (!mpAccount) throw new HttpError(409, 'No Mercado Pago account connected');
    mpAccount = await refreshMercadoPagoAccountIfNeeded(mpAccount, { client });

    const preference = await createPreference({
      accessToken: mpAccount.accessToken,
      order,
      items: itemRows,
      successUrl,
    });

    await client.query(
      `UPDATE orders
       SET mp_account_id = $2,
           mp_preference_id = $3
       WHERE id = $1 AND business_id = $4`,
      [order.id, mpAccount.id, preference.id, businessId]
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
       WHERE id = $1 AND business_id = $2`,
      [req.params.id, req.auth.businessId]
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
