import { Router } from 'express';
import { exchangeOAuthCode, getAccountStatus, getApprovedPaymentsTotal } from '../lib/mercadoPago.js';
import { getLatestMercadoPagoAccount, refreshMercadoPagoAccountIfNeeded, saveMercadoPagoAccount } from '../lib/mpAccounts.js';
import HttpError from '../lib/httpError.js';

const router = Router();

function validateIsoDate(value, field) {
  if (!value || Number.isNaN(Date.parse(value))) throw new HttpError(400, `${field} is required and must be a valid date`);
  return new Date(value).toISOString();
}

router.post('/oauth/exchange', async (req, res, next) => {
  try {
    const { code, code_verifier, redirect_uri } = req.body;
    if (!code?.trim()) throw new HttpError(400, 'code is required');
    if (!code_verifier?.trim()) throw new HttpError(400, 'code_verifier is required');

    const token = await exchangeOAuthCode({
      code: code.trim(),
      codeVerifier: code_verifier.trim(),
      redirectUri: redirect_uri,
    });

    if (!token.access_token || !token.user_id) {
      throw new HttpError(502, 'Mercado Pago OAuth response is missing required fields', token);
    }

    const account = await saveMercadoPagoAccount({
      businessId: req.auth.businessId,
      token,
    });

    res.json({
      mp_account_id: account.id,
      mp_user_id: account.mp_user_id,
      expires_at: account.expires_at,
      scopes: account.scopes,
    });
  } catch (err) {
    next(err);
  }
});

router.get('/account/status', async (req, res, next) => {
  try {
    let account = await getLatestMercadoPagoAccount({ businessId: req.auth.businessId });
    if (!account) throw new HttpError(404, 'No Mercado Pago account connected');
    account = await refreshMercadoPagoAccountIfNeeded(account);
    const status = await getAccountStatus({ accessToken: account.accessToken });

    res.json({
      mp_account_id: account.id,
      mp_user_id: account.mpUserId,
      expires_at: account.expiresAt,
      scopes: account.scopes,
      account: status,
    });
  } catch (err) {
    next(err);
  }
});

router.get('/payments/total', async (req, res, next) => {
  try {
    const beginDate = validateIsoDate(req.query.begin_date, 'begin_date');
    const endDate = req.query.end_date ? validateIsoDate(req.query.end_date, 'end_date') : null;
    let account = await getLatestMercadoPagoAccount({ businessId: req.auth.businessId });
    if (!account) throw new HttpError(404, 'No Mercado Pago account connected');
    account = await refreshMercadoPagoAccountIfNeeded(account);

    const total = await getApprovedPaymentsTotal({
      accessToken: account.accessToken,
      beginDate,
      endDate,
    });

    res.json(total);
  } catch (err) {
    next(err);
  }
});

export default router;
