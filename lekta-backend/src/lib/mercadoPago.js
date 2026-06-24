import config, { requireConfig } from '../config.js';
import HttpError from './httpError.js';

const MP_API_BASE_URL = 'https://api.mercadopago.com';

async function parseResponse(response) {
  const text = await response.text();
  if (!text) return {};

  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

async function mercadoPagoRequest(path, { accessToken, method = 'GET', body, headers = {} } = {}) {
  const response = await fetch(`${MP_API_BASE_URL}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const data = await parseResponse(response);
  if (!response.ok) {
    throw new HttpError(response.status, 'Mercado Pago request failed', data);
  }
  return data;
}

export async function exchangeOAuthCode({ code, codeVerifier, redirectUri }) {
  requireConfig(['mpClientId', 'mpClientSecret', 'mpRedirectUri']);

  const form = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: config.mpClientId,
    client_secret: config.mpClientSecret,
    code,
    redirect_uri: redirectUri || config.mpRedirectUri,
  });

  if (codeVerifier) form.set('code_verifier', codeVerifier);

  const response = await fetch(`${MP_API_BASE_URL}/oauth/token`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: form,
  });

  const data = await parseResponse(response);
  if (!response.ok) {
    throw new HttpError(response.status, 'Mercado Pago OAuth exchange failed', data);
  }

  return data;
}

export async function createPreference({ accessToken, order, items, successUrl }) {
  requireConfig(['mpNotificationUrl']);

  const body = {
    items: items.map(item => ({
      id: item.barcode || item.id,
      title: item.title,
      quantity: Number(item.quantity),
      unit_price: Number(item.unit_price),
      currency_id: order.currency,
    })),
    external_reference: order.external_reference,
    notification_url: config.mpNotificationUrl,
    metadata: {
      order_id: order.id,
      operator_id: order.operator_id,
      cash_session_id: order.cash_session_id,
      device_id: order.device_id,
    },
  };

  if (successUrl) {
    body.back_urls = { success: successUrl };
  }

  return mercadoPagoRequest('/checkout/preferences', {
    accessToken,
    method: 'POST',
    body,
  });
}

export async function getPayment({ accessToken, paymentId }) {
  return mercadoPagoRequest(`/v1/payments/${paymentId}`, { accessToken });
}

export function oauthExpiresAt(expiresInSeconds) {
  if (!expiresInSeconds) return null;
  return new Date(Date.now() + Number(expiresInSeconds) * 1000);
}
