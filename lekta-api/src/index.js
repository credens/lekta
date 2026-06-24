import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import config from './config.js';
import authRoutes from './routes/auth.js';
import operatorRoutes from './routes/operators.js';
import deviceRoutes from './routes/devices.js';
import productRoutes from './routes/products.js';
import cajaRoutes from './routes/caja.js';

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.get('/health', (_, res) => res.json({ status: 'ok', version: '1.0.0' }));

app.use('/auth', authRoutes);
app.use('/operators', operatorRoutes);
app.use('/devices', deviceRoutes);
app.use('/products', productRoutes);
app.use('/caja', cajaRoutes);

app.use((err, _req, res, _next) => {
  console.error('Unhandled error:', err.message);
  res.status(500).json({ error: 'Error interno del servidor' });
});

app.listen(config.port, () => {
  console.log(`Lekta API running on port ${config.port}`);
});
