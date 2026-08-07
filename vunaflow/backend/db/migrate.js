/**
 * Simple migration runner: executes db/schema.sql against the configured database.
 * Usage: npm run migrate
 */
const fs = require('fs');
const path = require('path');
require('dotenv').config();
const pool = require('../config/db');

async function migrate() {
  const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  const client = await pool.connect();
  try {
    console.log('Running schema.sql ...');
    await client.query(sql);
    console.log('✅ Database schema created and seeded successfully.');
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

migrate();
