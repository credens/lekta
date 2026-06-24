import { Router } from 'express';
import pool from '../db.js';
import { getPayment } from '../lib/mercadoPago.js';
import { listMercadoPagoAccounts, refreshMercadoPagoAccountIfNeeded } from '../lib/mpAccounts.js';
import { mapPaymentStatus } from '../lib/orders.js';

const router = Router();

function extractResourceId(req) {
  const body = req.body || {};
  const resource = body.resource || body.data?.id || req.query.id || req.query['data.id'];
  if (!resource) return null;

  const value = String(resource);
  const parts = value.split('/').filter(Boolean);
  return parts[parts.length - 1] || value;
}

function extractTopic(req) {
  return req.body?.type || req.body?.topic || req.query.type || req.query.topic || null;
}

function extractAction(req) {
  return req.body?.action || req.query.action || null;
}

function makeIdempotencyKey({ topic, action, resourceId }) {
  const parts = [topic || 'unknown-topic', action || 'unknown-action', resourceId || 'unknown-resource'];
  return parts.join(':');
}

async function fetchPaymentWithAnyAccount(paymentId) {
  const accounts = await listMercadoPagoAccounts();

  let lastError;
  for (const candidate of accounts) {
    try {
      const account = await refreshMercadoPagoAccountIfNeeded(candidate);
      const payment = await getPayment({ accessToken: account.accessToken, paymentId });
      return { payment, account };
    } catch (err) {
      lastError = err;
    }
  }

  throw lastError || new Error('No Mercado Pago account connected');
}

router.post('/mercadopago', async (req, res, next) => {
  const resourceId = extractResourceId(req);
  const topic = extractTopic(req);
  const action = extractAction(req);
  const rawPayload = { body: req.body, query: req.query };
  const idempotencyKey = makeIdempotencyKey({ topic, action, resourceId });

  const client = await pool.connect();
  let transactionStarted = false;
  let eventId = null;
  try {
    const { rows: eventRows } = await client.query(
      `INSERT INTO mp_webhook_events (topic, resource_id, action, idempotency_key, raw_payload)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (idempotency_key) DO NOTHING
       RETURNING id`,
      [topic, resourceId, action, idempotencyKey, rawPayload]
    );

    if (!eventRows[0]) {
      return res.sendStatus(200);
    }

    eventId = eventRows[0].id;
    const isPayment = topic === 'payment' || topic === 'payments' || action?.startsWith('payment.');
    if (!resourceId || !isPayment) {
      await client.query(
        `UPDATE mp_webhook_events
         SET processed_at = now(), processed = true, status = 'ignored'
         WHERE id = $1`,
        [eventId]
      );
      return res.sendStatus(200);
    }

    const { payment, account } = await fetchPaymentWithAnyAccount(resourceId);
    const externalReference = payment.external_reference;
    const orderStatus = mapPaymentStatus(payment.status);

    await client.query('BEGIN');
    transactionStarted = true;

    const { rows: orderRows } = await client.query(
      `SELECT id, status
       FROM orders
       WHERE external_reference = $1
       FOR UPDATE`,
      [externalReference]
    );

    if (!orderRows[0]) {
      await client.query(
        `UPDATE mp_webhook_events
         SET processed_at = now(), processed = true, status = 'order_not_found'
         WHERE id = $1`,
        [eventId]
      );
      await client.query('COMMIT');
      return res.sendStatus(200);
    }

    const approvedAt =
      orderStatus === 'approved'
        ? (payment.date_approved ? new Date(payment.date_approved) : new Date())
        : null;

    await client.query(
      `UPDATE orders
       SET status = CASE
             WHEN status = 'approved' AND $2 <> 'approved' THEN status
             ELSE $2
           END,
           status_detail = $3,
           mp_account_id = COALESCE(mp_account_id, $4),
           mp_payment_id = $5,
           mp_status = $6,
           approved_at = CASE WHEN $2 = 'approved' THEN COALESCE(approved_at, $7) ELSE approved_at END
       WHERE id = $1`,
      [
        orderRows[0].id,
        orderStatus,
        payment.status_detail || payment.status || null,
        account.id,
        String(payment.id),
        payment.status || null,
        approvedAt,
      ]
    );

    await client.query(
      `UPDATE mp_webhook_events
       SET processed_at = now(), processed = true, status = 'processed'
       WHERE id = $1`,
      [eventId]
    );

    await client.query('COMMIT');
    res.sendStatus(200);
  } catch (err) {
    if (transactionStarted) await client.query('ROLLBACK');
    if (eventId) {
      await pool.query(
        `UPDATE mp_webhook_events
         SET processed_at = now(), processed = false, status = 'error'
         WHERE id = $1`,
        [eventId]
      );
    }
    next(err);
  } finally {
    client.release();
  }
});

export default router;
