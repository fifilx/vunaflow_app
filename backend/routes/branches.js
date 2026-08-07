const express = require('express');
const pool = require('../config/db');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

// Public: list branches (needed on registration form before login)
router.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM branches ORDER BY name ASC');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not fetch branches' });
  }
});

// Admin: add a branch
router.post('/', authenticate, authorize('admin'), async (req, res) => {
  const { name, code, county, address, phone } = req.body;
  if (!name || !code) return res.status(400).json({ error: 'name and code are required' });
  try {
    const result = await pool.query(
      `INSERT INTO branches (name, code, county, address, phone) VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [name, code, county || null, address || null, phone || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not create branch' });
  }
});

module.exports = router;
