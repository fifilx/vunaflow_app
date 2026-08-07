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
    farming_type,
    primary_crop,
    livestock_type,
    livestock_count,
    years_farming,
    has_collateral,
  } = req.body;

  if (national_id && !/^[0-9]{7,8}$/.test(national_id)) {
    return res.status(400).json({ error: 'National ID must be 7 or 8 digits' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    let normalizedPhone;
    if (phone) {
      try {
        normalizedPhone = normalizeKenyanPhone(phone);
      } catch (e) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: e.message });
      }
    }

    if (full_name || phone || branch_id) {
      await client.query(
        `UPDATE users SET
           full_name = COALESCE($1, full_name),
           phone = COALESCE($2, phone),
           branch_id = COALESCE($3, branch_id),
           updated_at = now()
         WHERE id = $4`,
        [full_name ? toTitleCase(full_name) : null, normalizedPhone || null, branch_id || null, req.user.id]
      );
    }

    const upsert = await client.query(
      `INSERT INTO farmer_profiles
         (user_id, national_id, date_of_birth, gender, address, county,
          farm_location, farm_size_acres, farming_type, primary_crop, livestock_type, livestock_count, years_farming, has_collateral)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
       ON CONFLICT (user_id) DO UPDATE SET
         national_id = COALESCE(EXCLUDED.national_id, farmer_profiles.national_id),
         date_of_birth = COALESCE(EXCLUDED.date_of_birth, farmer_profiles.date_of_birth),
         gender = COALESCE(EXCLUDED.gender, farmer_profiles.gender),
         address = COALESCE(EXCLUDED.address, farmer_profiles.address),
         county = COALESCE(EXCLUDED.county, farmer_profiles.county),
         farm_location = COALESCE(EXCLUDED.farm_location, farmer_profiles.farm_location),
         farm_size_acres = COALESCE(EXCLUDED.farm_size_acres, farmer_profiles.farm_size_acres),
         farming_type = COALESCE(EXCLUDED.farming_type, farmer_profiles.farming_type),
         primary_crop = COALESCE(EXCLUDED.primary_crop, farmer_profiles.primary_crop),
         livestock_type = COALESCE(EXCLUDED.livestock_type, farmer_profiles.livestock_type),
         livestock_count = COALESCE(EXCLUDED.livestock_count, farmer_profiles.livestock_count),
         years_farming = COALESCE(EXCLUDED.years_farming, farmer_profiles.years_farming),
         has_collateral = COALESCE(EXCLUDED.has_collateral, farmer_profiles.has_collateral),
         updated_at = now()
       RETURNING *`,
      [
        req.user.id,
        national_id || null,
        date_of_birth || null,
        gender || null,
        address || null,
        county || null,
        farm_location || null,
        farm_size_acres ?? null,
        farming_type || null,
        primary_crop || null,
        livestock_type || null,
        livestock_count ?? null,
        years_farming ?? null,
        has_collateral ?? null,
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

// POST /api/profile/overpayment/transfer - transfer overpayment credit balance to active unpaid loan
router.post('/overpayment/transfer', async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const profileRes = await client.query('SELECT * FROM farmer_profiles WHERE user_id = $1', [req.user.id]);
    if (profileRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Farmer profile not found' });
    }

    const overpaymentBalance = Number(profileRes.rows[0].overpayment_balance || 0);
    if (overpaymentBalance <= 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'You do not have any overpayment credit to transfer.' });
    }

    const loansRes = await client.query(
      `SELECT * FROM loan_applications 
       WHERE client_id = $1 AND status IN ('disbursed', 'approved') AND COALESCE(amount_paid, 0) < amount_requested 
       ORDER BY created_at ASC LIMIT 1`,
      [req.user.id]
    );

    if (loansRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'You do not have an active loan with an unpaid balance to transfer funds to.' });
    }

    const targetLoan = loansRes.rows[0];
    const reqAmt = Number(targetLoan.amount_requested);
    const paidAmt = Number(targetLoan.amount_paid || 0);
    const remaining = Math.max(0, reqAmt - paidAmt);

    const transferAmt = Math.min(overpaymentBalance, remaining);

    if (transferAmt <= 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'The active loan is already fully paid.' });
    }

    await client.query(
      `UPDATE loan_applications SET amount_paid = COALESCE(amount_paid, 0) + $1, updated_at = now() WHERE id = $2`,
      [transferAmt, targetLoan.id]
    );

    const newOverpayment = overpaymentBalance - transferAmt;
    await client.query(
      `UPDATE farmer_profiles SET overpayment_balance = $1, updated_at = now() WHERE user_id = $2`,
      [newOverpayment, req.user.id]
    );

    const ref = `OVP-XFR-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
    await client.query(
      `INSERT INTO payments (loan_id, client_id, amount, payment_method, transaction_ref, status) VALUES ($1,$2,$3,'Overpayment Transfer',$4,'completed')`,
      [targetLoan.id, req.user.id, transferAmt, ref]
    );

    await client.query(
      `INSERT INTO notifications (user_id, title, message) VALUES ($1,$2,$3)`,
      [
        req.user.id,
        '🔄 Credit Transferred to Loan',
        `KSh ${transferAmt.toLocaleString()} from your Overpayment Credit was transferred to pay off your active loan (Account No: ${targetLoan.account_number || 'N/A'}).`
      ]
    );

    await client.query('COMMIT');
    res.json({
      message: `Successfully transferred KSh ${transferAmt.toLocaleString()} to your active loan!`,
      transferred_amount: transferAmt,
      remaining_overpayment: newOverpayment,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Could not process overpayment transfer' });
  } finally {
    client.release();
  }
});

// POST /api/profile/overpayment/refund - request refund of overpayment credit
router.post('/overpayment/refund', async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const profileRes = await client.query('SELECT * FROM farmer_profiles WHERE user_id = $1', [req.user.id]);
    if (profileRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Farmer profile not found' });
    }

    const overpaymentBalance = Number(profileRes.rows[0].overpayment_balance || 0);
    if (overpaymentBalance <= 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'You do not have any overpayment credit balance to refund.' });
    }

    await client.query(
      `UPDATE farmer_profiles SET overpayment_balance = 0, updated_at = now() WHERE user_id = $1`,
      [req.user.id]
    );

    await client.query(
      `INSERT INTO notifications (user_id, title, message) VALUES ($1,$2,$3)`,
      [
        req.user.id,
        '💸 Refund Request Submitted',
        `Your refund request for KSh ${overpaymentBalance.toLocaleString()} has been received. AFC Branch staff will process the payout to your M-Pesa account.`
      ]
    );

    await client.query('COMMIT');
    res.json({
      message: `Refund request for KSh ${overpaymentBalance.toLocaleString()} submitted successfully!`,
      refunded_amount: overpaymentBalance,
    });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Could not process refund request' });
  } finally {
    client.release();
  }
});

module.exports = router;
