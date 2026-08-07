/**
 * seed-sandbox-ledger.js
 * Creates the mpesa_sandbox_ledger table and seeds it with KSh 500 billion.
 */
require('dotenv').config();
const pool = require('../config/db');

async function run() {
  const client = await pool.connect();
  try {
    // 1. Create table
    await client.query(`
      CREATE TABLE IF NOT EXISTS mpesa_sandbox_ledger (
        id         SERIAL PRIMARY KEY,
        balance    NUMERIC(20,2) NOT NULL DEFAULT 0,
        updated_at TIMESTAMPTZ DEFAULT now()
      )
    `);
    console.log('Table ready: mpesa_sandbox_ledger');

    // 2. Check for existing row
    const existing = await client.query('SELECT id FROM mpesa_sandbox_ledger LIMIT 1');

    if (existing.rows.length === 0) {
      await client.query(
        'INSERT INTO mpesa_sandbox_ledger (balance) VALUES ($1)',
        [500000000000.00]
      );
      console.log('Seeded with KSh 500,000,000,000');
    } else {
      await client.query(
        'UPDATE mpesa_sandbox_ledger SET balance = $1, updated_at = now() WHERE id = 1',
        [500000000000.00]
      );
      console.log('Reset to KSh 500,000,000,000');
    }

    const res = await client.query('SELECT balance FROM mpesa_sandbox_ledger LIMIT 1');
    console.log('Current sandbox balance: KSh', Number(res.rows[0].balance).toLocaleString());
  } catch (err) {
    console.error('Error:', err.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

run();
