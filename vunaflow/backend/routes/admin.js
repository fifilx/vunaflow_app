const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const pool = require('../config/db');
const { authenticate, authorize } = require('../middleware/auth');
const { normalizeKenyanPhone } = require('../utils/phone');
const { toTitleCase } = require('../utils/text');

const router = express.Router();
router.use(authenticate, authorize('admin'));

// GET /api/admin/staff - list all staff/admin users
router.get('/staff', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.id, u.full_name, u.email, u.phone, u.role, u.is_active, u.created_at,
              b.name AS branch_name, sp.employee_no, sp.department, sp.status
       FROM users u
       LEFT JOIN branches b ON u.branch_id = b.id
       LEFT JOIN staff_profiles sp ON sp.user_id = u.id
       WHERE u.role IN ('staff','admin')
       ORDER BY u.created_at DESC`
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not fetch staff' });
  }
});

// POST /api/admin/staff - add a new staff member
router.post(
  '/staff',
  [
    body('full_name').trim().notEmpty(),
    body('email').isEmail(),
    body('phone').trim().notEmpty(),
    body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
    body('role').isIn(['staff', 'admin']),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { full_name, email, password, role, branch_id, employee_no, department } = req.body;

    const normalizedPhone = normalizeKenyanPhone(req.body.phone);
    if (!normalizedPhone) {
      return res.status(400).json({
        error: 'Enter a valid Kenyan phone number, e.g. 0712345678, 0112345678, or +254712345678',
      });
    }
    const phone = normalizedPhone;

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const existing = await client.query('SELECT id FROM users WHERE email = $1', [email]);
      if (existing.rows.length > 0) {
        await client.query('ROLLBACK');
        return res.status(409).json({ error: 'A user with this email already exists' });
      }

      const password_hash = await bcrypt.hash(password, 10);
      const userResult = await client.query(
        `INSERT INTO users (full_name, email, phone, password_hash, role, branch_id)
         VALUES ($1,$2,$3,$4,$5,$6) RETURNING id, full_name, email, phone, role, branch_id`,
        [toTitleCase(full_name), email, phone, password_hash, role, branch_id || null]
      );
      const user = userResult.rows[0];

      await client.query(
        `INSERT INTO staff_profiles (user_id, employee_no, department, status) VALUES ($1,$2,$3,'active')`,
        [user.id, employee_no || null, department || null]
      );

      await client.query('COMMIT');
      res.status(201).json(user);
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(err);
      res.status(500).json({ error: 'Could not create staff account' });
    } finally {
      client.release();
    }
  }
);

// PATCH /api/admin/staff/:id/disable - disable a staff account
router.patch('/staff/:id/disable', async (req, res) => {
  try {
    await pool.query('UPDATE users SET is_active = false WHERE id = $1', [req.params.id]);
    await pool.query(`UPDATE staff_profiles SET status = 'disabled' WHERE user_id = $1`, [req.params.id]);
    res.json({ message: 'Staff account disabled' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not disable account' });
  }
});

// PATCH /api/admin/staff/:id/enable - re-enable a staff account
router.patch('/staff/:id/enable', async (req, res) => {
  try {
    await pool.query('UPDATE users SET is_active = true WHERE id = $1', [req.params.id]);
    await pool.query(`UPDATE staff_profiles SET status = 'active' WHERE user_id = $1`, [req.params.id]);
    res.json({ message: 'Staff account enabled' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not enable account' });
  }
});

// PATCH /api/admin/staff/:id/role - assign a role (staff <-> admin)
router.patch('/staff/:id/role', [body('role').isIn(['staff', 'admin'])], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  try {
    const result = await pool.query('UPDATE users SET role = $1 WHERE id = $2 RETURNING id, role', [
      req.body.role,
      req.params.id,
    ]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not update role' });
  }
});

module.exports = router;
