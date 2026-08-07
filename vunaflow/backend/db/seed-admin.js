/**
 * Creates (or updates) the first admin account so you can log in via the
 * Staff Login screen without writing any SQL by hand.
 *
 * Usage:
 *   npm run seed:admin
 *   npm run seed:admin -- --email=admin@afc.co.ke --password=Admin@12345 --name="AFC Administrator" --phone=0700000000
 *
 * If you don't pass flags, sensible defaults are used (printed at the end).
 */
require('dotenv').config();
const bcrypt = require('bcryptjs');
const pool = require('../config/db');

function getArg(name, fallback) {
  const prefix = `--${name}=`;
  const found = process.argv.find((a) => a.startsWith(prefix));
  return found ? found.slice(prefix.length) : fallback;
}

async function seedAdmin() {
  const email = getArg('email', 'admin@afc.co.ke');
  const password = getArg('password', 'Admin@12345');
  const fullName = getArg('name', 'AFC Administrator');
  const phone = getArg('phone', '0700000000');

  const client = await pool.connect();
  try {
    const password_hash = await bcrypt.hash(password, 10);

    const existing = await client.query('SELECT id FROM users WHERE email = $1', [email]);

    let userId;
    if (existing.rows.length > 0) {
      userId = existing.rows[0].id;
      await client.query(
        `UPDATE users SET password_hash = $1, role = 'admin', full_name = $2, phone = $3, is_active = true WHERE id = $4`,
        [password_hash, fullName, phone, userId]
      );
      console.log(`ℹ️  Existing user found for ${email} — updated to admin with the new password.`);
    } else {
      const result = await client.query(
        `INSERT INTO users (full_name, email, phone, password_hash, role)
         VALUES ($1, $2, $3, $4, 'admin') RETURNING id`,
        [fullName, email, phone, password_hash]
      );
      userId = result.rows[0].id;
      console.log(`✅ Created new admin user: ${email}`);
    }

    await client.query(
      `INSERT INTO staff_profiles (user_id, status)
       VALUES ($1, 'active')
       ON CONFLICT (user_id) DO UPDATE SET status = 'active'`,
      [userId]
    );

    console.log('\n============================================');
    console.log(' VunaFlow Admin Account Ready');
    console.log('============================================');
    console.log(` Email:    ${email}`);
    console.log(` Password: ${password}`);
    console.log(' Log in via the Staff Login screen in the app.');
    console.log(' You can then use the Admin tab to add more staff.');
    console.log('============================================\n');
  } catch (err) {
    console.error('❌ Could not seed admin account:', err.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

seedAdmin();
