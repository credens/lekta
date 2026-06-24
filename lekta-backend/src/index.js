import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import config from './config.js';
import checkoutRoutes from './routes/checkout.js';
import mpOAuthRoutes from './routes/mpOAuth.js';
import webhookRoutes from './routes/webhooks.js';
import HttpError from './lib/httpError.js';

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'lekta-backend' });
});

app.use('/api/mp', mpOAuthRoutes);
app.use('/api/checkout', checkoutRoutes);
app.use('/api/webhooks', webhookRoutes);

app.use((req, _res, next) => {
  next(new HttpError(404, `Route not found: ${req.method} ${req.path}`));
});

app.use((err, _req, res, _next) => {
  const statusCode = err.statusCode || 500;
  if (statusCode >= 500) {
    console.error('Unhandled error:', err.message, err.details || '');
  }

  res.status(statusCode).json({
    error: err.message || 'Internal server error',
    ...(err.details ? { details: err.details } : {}),
  });
});

app.listen(config.port, () => {
  console.log(`Lekta backend listening on port ${config.port}`);
});
