import { readdirSync, readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import pool from './db.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

async function migrate() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS migrations (
        id SERIAL PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        applied_at TIMESTAMPTZ DEFAULT now()
      )
    `);

    const { rows: applied } = await client.query('SELECT name FROM migrations ORDER BY id');
    const appliedNames = new Set(applied.map(row => row.name));
    const files = readdirSync(join(__dirname, 'migrations'))
      .filter(file => file.endsWith('.sql'))
      .sort();

    for (const file of files) {
      if (appliedNames.has(file)) {
        console.log(`skip: ${file}`);
        continue;
      }

      const sql = readFileSync(join(__dirname, 'migrations', file), 'utf8');
      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO migrations (name) VALUES ($1)', [file]);
      await client.query('COMMIT');
      console.log(`applied: ${file}`);
    }

    console.log('Migrations complete.');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Migration failed:', err.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

migrate();
