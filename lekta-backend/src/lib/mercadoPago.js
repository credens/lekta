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

async function oauthTokenRequest(form, errorMessage) {
  requireConfig(['mpClientId', 'mpClientSecret']);
  form.set('client_id', config.mpClientId);
  form.set('client_secret', config.mpClientSecret);

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
    throw new HttpError(response.status, errorMessage, data);
  }

  return data;
}

export async function exchangeOAuthCode({ code, codeVerifier, redirectUri }) {
  requireConfig(['mpRedirectUri']);

  const form = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: redirectUri || config.mpRedirectUri,
  });

  if (codeVerifier) form.set('code_verifier', codeVerifier);
  return oauthTokenRequest(form, 'Mercado Pago OAuth exchange failed');
}

export async function refreshOAuthToken({ refreshToken }) {
  const form = new URLSearchParams({
    grant_type: 'refresh_token',
    refresh_token: refreshToken,
  });

  return oauthTokenRequest(form, 'Mercado Pago OAuth refresh failed');
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
      business_id: order.business_id,
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
  return mercadoPagoRequest(`/v1/payments/${encodeURIComponent(paymentId)}`, { accessToken });
}

export async function getAccountStatus({ accessToken }) {
  const account = await mercadoPagoRequest('/users/me', { accessToken });
  return {
    mp_user_id: account.id ? String(account.id) : null,
    nickname: account.nickname || null,
    site_id: account.site_id || null,
    status: account.status || null,
  };
}

export async function getApprovedPaymentsTotal({ accessToken, beginDate, endDate }) {
  const params = new URLSearchParams({
    sort: 'date_created',
    criteria: 'desc',
    range: 'date_created',
    begin_date: beginDate,
    status: 'approved',
    limit: '50',
  });
  if (endDate) params.set('end_date', endDate);

  let offset = 0;
  let totalAmount = 0;
  let count = 0;
  let pagingTotal = null;

  for (let page = 0; page < 20; page += 1) {
    params.set('offset', String(offset));
    const data = await mercadoPagoRequest(`/v1/payments/search?${params.toString()}`, { accessToken });
    const results = Array.isArray(data.results) ? data.results : [];
    pagingTotal = data.paging?.total ?? pagingTotal;

    for (const payment of results) {
      if (payment.status === 'approved') {
        totalAmount += Number(payment.transaction_amount || 0);
        count += 1;
      }
    }

    if (!results.length || results.length < 50) break;
    offset += results.length;
  }

  return { begin_date: beginDate, end_date: endDate || null, count, total_amount: Math.round(totalAmount * 100) / 100, paging_total: pagingTotal };
}

export function oauthExpiresAt(expiresInSeconds) {
  if (!expiresInSeconds) return null;
  return new Date(Date.now() + Number(expiresInSeconds) * 1000);
}
