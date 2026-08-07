const express = require('express');
const pool = require('../config/db');
const { authenticate } = require('../middleware/auth');
const { normalizeKenyanPhone } = require('../utils/phone');
const { toTitleCase } = require('../utils/text');

const router = express.Router();
router.use(authenticate);

// GET /api/profile - current user's combined account + farmer profile
router.get('/', async (req, res) => {
  try {
    const userResult = await pool.query(
      `SELECT u.id, u.full_name, u.email, u.phone, u.role, u.created_at,
              b.name AS branch_name, b.id AS branch_id
       FROM users u LEFT JOIN branches b ON u.branch_id = b.id
       WHERE u.id = $1`,
      [req.user.id]
    );
    if (userResult.rows.length === 0) return res.status(404).json({ error: 'User not found' });

    const profileResult = await pool.query('SELECT * FROM farmer_profiles WHERE user_id = $1', [req.user.id]);

    res.json({
      account: userResult.rows[0],
      farmer_profile: profileResult.rows[0] || null,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not fetch profile' });
  }
});

// PUT /api/profile - edit personal + farm information
router.put('/', async (req, res) => {
  const {
    full_name,
    phone,
    branch_id,
    national_id,
    date_of_birth,
    gender,
    address,
    county,
    farm_location,
    farm_size_acres,
    primary_crop,
    years_farming,
    has_collateral,
  } = req.body;

  if (national_id && !/^[0-9]{7,8}$/.test(national_id)) {
    return res.status(400).json({ error: 'National ID must be 7 or 8 digits' });
  }

  let normalizedPhone = phone;
  if (phone) {
    normalizedPhone = normalizeKenyanPhone(phone);
    if (!normalizedPhone) {
      return res.status(400).json({
        error: 'Enter a valid Kenyan phone number, e.g. 0712345678, 0112345678, or +254712345678',
      });
    }
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    if (full_name || normalizedPhone || branch_id) {
      await client.query(
        `UPDATE users SET
           full_name = COALESCE($1, full_name),
           phone = COALESCE($2, phone),
           branch_id = COALESCE($3, branch_id),
           updated_at = now()
         WHERE id = $4`,
        [full_name ? toTitleCase(full_name) : null, normalizedPhone, branch_id, req.user.id]
      );
    }

    const upsert = await client.query(
      `INSERT INTO farmer_profiles
         (user_id, national_id, date_of_birth, gender, address, county,
          farm_location, farm_size_acres, primary_crop, years_farming, has_collateral)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
       ON CONFLICT (user_id) DO UPDATE SET
         national_id = COALESCE(EXCLUDED.national_id, farmer_profiles.national_id),
         date_of_birth = COALESCE(EXCLUDED.date_of_birth, farmer_profiles.date_of_birth),
         gender = COALESCE(EXCLUDED.gender, farmer_profiles.gender),
         address = COALESCE(EXCLUDED.address, farmer_profiles.address),
         county = COALESCE(EXCLUDED.county, farmer_profiles.county),
         farm_location = COALESCE(EXCLUDED.farm_location, farmer_profiles.farm_location),
         farm_size_acres = COALESCE(EXCLUDED.farm_size_acres, farmer_profiles.farm_size_acres),
         primary_crop = COALESCE(EXCLUDED.primary_crop, farmer_profiles.primary_crop),
         years_farming = COALESCE(EXCLUDED.years_farming, farmer_profiles.years_farming),
         has_collateral = COALESCE(EXCLUDED.has_collateral, farmer_profiles.has_collateral),
         updated_at = now()
       RETURNING *`,
      [
        req.user.id,
        national_id,
        date_of_birth,
        gender,
        address,
        county,
        farm_location,
        farm_size_acres,
        primary_crop,
        years_farming,
        has_collateral,
      ]
    );

    await client.query('COMMIT');
    res.json({ message: 'Profile updated successfully', farmer_profile: upsert.rows[0] });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Could not update profile' });
  } finally {
    client.release();
  }
});

module.exports = router;
