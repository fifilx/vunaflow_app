const express = require('express');
const { body, validationResult } = require('express-validator');
const pool = require('../config/db');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);

const VALID_STATUSES = [
  'submitted',
  'under_review',
  'documents_verified',
  'approved',
  'rejected',
  'disbursed',
];

async function notify(userId, title, message) {
  await pool.query('INSERT INTO notifications (user_id, title, message) VALUES ($1,$2,$3)', [
    userId,
    title,
    message,
  ]);
}

/**
 * POST /api/loans
 * Submit a new loan application. Validates amount >= 100,000.
 * Also runs the rule-based eligibility checker and stores the result.
 */
router.post(
  '/',
  authorize('client'),
  [
    body('amount_requested')
      .isFloat({ min: 100000 })
      .withMessage('Loan amount must be at least KSh 100,000'),
    body('purpose').trim().notEmpty().withMessage('Purpose is required'),
    body('repayment_period_months').isInt({ min: 1 }).withMessage('Repayment period is required'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { amount_requested, purpose, repayment_period_months, branch_id } = req.body;

    try {
      const userResult = await pool.query('SELECT branch_id FROM users WHERE id = $1', [req.user.id]);
      const profileResult = await pool.query('SELECT * FROM farmer_profiles WHERE user_id = $1', [req.user.id]);
      const profile = profileResult.rows[0];

      // Require a complete farmer profile before a loan can be submitted at all.
      const missingFields = [];
      if (!profile?.national_id) missingFields.push('National ID');
      if (!profile?.date_of_birth) missingFields.push('Date of Birth');
      if (!profile?.farm_size_acres) missingFields.push('Farm Size');
      if (!profile?.primary_crop) missingFields.push('Primary Crop');
      if (missingFields.length > 0) {
        return res.status(400).json({
          error: `Please complete your farmer profile before applying for a loan. Missing: ${missingFields.join(', ')}.`,
          code: 'PROFILE_INCOMPLETE',
        });
      }

      // Hard age gate: applicants must be 18 or older.
      const dob = new Date(profile.date_of_birth);
      const age = Math.floor((Date.now() - dob.getTime()) / (365.25 * 24 * 3600 * 1000));
      if (age < 18) {
        return res.status(403).json({
          error: 'You must be at least 18 years old to apply for a loan.',
          code: 'UNDER_AGE',
        });
      }

      const eligibility = evaluateEligibility({
        farm_size_acres: profile?.farm_size_acres,
        amount_requested,
        has_collateral: profile?.has_collateral,
        date_of_birth: profile?.date_of_birth,
      });

      const resolvedBranchId = branch_id || userResult.rows[0]?.branch_id || null;

      const result = await pool.query(
        `INSERT INTO loan_applications
           (client_id, branch_id, amount_requested, purpose, repayment_period_months, status, eligibility_result)
         VALUES ($1,$2,$3,$4,$5,'submitted',$6)
         RETURNING *`,
        [req.user.id, resolvedBranchId, amount_requested, purpose, repayment_period_months, eligibility.result]
      );
      const loan = result.rows[0];

      await pool.query(
        `INSERT INTO loan_status_history (loan_id, status, changed_by, comment) VALUES ($1,'submitted',$2,'Application submitted by client')`,
        [loan.id, req.user.id]
      );

      await notify(
        req.user.id,
        'Loan Application Submitted',
        `Your application for KSh ${Number(amount_requested).toLocaleString()} has been received and is now Submitted. Please visit any AFC branch for document verification.`
      );

      res.status(201).json({
        loan,
        eligibility,
        message: 'Your loan application has been submitted. Please visit any AFC branch for proper document verification.',
      });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Could not submit loan application' });
    }
  }
);

/**
 * GET /api/loans/eligibility-check
 * Simulated rule-based eligibility checker, can be called standalone
 * (before submitting an application) using query params or the saved profile.
 */
router.get('/eligibility-check', authorize('client'), async (req, res) => {
  try {
    const profileResult = await pool.query('SELECT * FROM farmer_profiles WHERE user_id = $1', [req.user.id]);
    const profile = profileResult.rows[0];
    const amount_requested = req.query.amount ? Number(req.query.amount) : undefined;

    const eligibility = evaluateEligibility({
      farm_size_acres: profile?.farm_size_acres,
      amount_requested,
      has_collateral: profile?.has_collateral,
      date_of_birth: profile?.date_of_birth,
    });

    res.json(eligibility);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not run eligibility check' });
  }
});

function evaluateEligibility({ farm_size_acres, amount_requested, has_collateral, date_of_birth }) {
  const reasons = [];
  let age = null;
  if (date_of_birth) {
    const dob = new Date(date_of_birth);
    age = Math.floor((Date.now() - dob.getTime()) / (365.25 * 24 * 3600 * 1000));
  }

  const checks = {
    farmSizeOk: (farm_size_acres ?? 0) >= 2,
    amountOk: (amount_requested ?? 0) <= 1000000,
    hasCollateral: !!has_collateral,
    ageOk: age === null ? null : age >= 18,
  };

  if (!checks.farmSizeOk) reasons.push('Farm size is below the recommended 2 acres');
  if (!checks.amountOk) reasons.push('Requested amount exceeds KSh 1,000,000');
  if (!checks.hasCollateral) reasons.push('No collateral on file');
  if (checks.ageOk === false) reasons.push('Applicant is under 18');
  if (checks.ageOk === null) reasons.push('Date of birth not provided');

  const likelyEligible =
    checks.farmSizeOk && checks.amountOk && checks.hasCollateral && checks.ageOk === true;

  return {
    result: likelyEligible ? 'Likely eligible' : 'May require further review',
    checks,
    reasons,
  };
}

/**
 * GET /api/loans/mine - client's own loan applications
 */
router.get('/mine', authorize('client'), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT l.*, b.name AS branch_name
       FROM loan_applications l LEFT JOIN branches b ON l.branch_id = b.id
       WHERE client_id = $1 ORDER BY created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not fetch applications' });
  }
});

/**
 * GET /api/loans/:id - loan detail with status history (owner or staff)
 */
router.get('/:id', async (req, res) => {
  try {
    const loanResult = await pool.query(
      `SELECT l.*, b.name AS branch_name, u.full_name AS client_name
       FROM loan_applications l
       LEFT JOIN branches b ON l.branch_id = b.id
       LEFT JOIN users u ON l.client_id = u.id
       WHERE l.id = $1`,
      [req.params.id]
    );
    if (loanResult.rows.length === 0) return res.status(404).json({ error: 'Loan not found' });
    const loan = loanResult.rows[0];

    if (req.user.role === 'client' && loan.client_id !== req.user.id) {
      return res.status(403).json({ error: 'Not authorized to view this application' });
    }

    const history = await pool.query(
      `SELECT h.*, u.full_name AS changed_by_name
       FROM loan_status_history h LEFT JOIN users u ON h.changed_by = u.id
       WHERE loan_id = $1 ORDER BY created_at ASC`,
      [req.params.id]
    );
    const documents = await pool.query('SELECT * FROM documents WHERE loan_id = $1', [req.params.id]);

    res.json({ loan, history: history.rows, documents: documents.rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not fetch loan detail' });
  }
});

/**
 * GET /api/loans - staff: list/search/filter all applications
 * Query params: status, branch_id, q (search by client name/email), page, limit
 */
router.get('/', authorize('staff', 'admin'), async (req, res) => {
  const { status, branch_id, q, page = 1, limit = 20 } = req.query;
  const conditions = [];
  const values = [];

  if (status && VALID_STATUSES.includes(status)) {
    values.push(status);
    conditions.push(`l.status = $${values.length}`);
  }
  if (branch_id) {
    values.push(branch_id);
    conditions.push(`l.branch_id = $${values.length}`);
  }
  if (q) {
    values.push(`%${q}%`);
    conditions.push(`(u.full_name ILIKE $${values.length} OR u.email ILIKE $${values.length})`);
  }

  const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const offset = (Number(page) - 1) * Number(limit);

  try {
    const result = await pool.query(
      `SELECT l.*, u.full_name AS client_name, u.email AS client_email, b.name AS branch_name
       FROM loan_applications l
       JOIN users u ON l.client_id = u.id
       LEFT JOIN branches b ON l.branch_id = b.id
       ${whereClause}
       ORDER BY l.created_at DESC
       LIMIT ${Number(limit)} OFFSET ${offset}`,
      values
    );
    const countResult = await pool.query(
      `SELECT COUNT(*) FROM loan_applications l JOIN users u ON l.client_id = u.id ${whereClause}`,
      values
    );
    res.json({ data: result.rows, total: Number(countResult.rows[0].count), page: Number(page), limit: Number(limit) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not fetch applications' });
  }
});

/**
 * PATCH /api/loans/:id/status - staff updates loan status manually
 * Body: { status, comment }
 */
router.patch('/:id/status', authorize('staff', 'admin'), async (req, res) => {
  const { status, comment } = req.body;
  if (!VALID_STATUSES.includes(status)) {
    return res.status(400).json({ error: `Status must be one of: ${VALID_STATUSES.join(', ')}` });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      `UPDATE loan_applications SET status = $1, reviewed_by = $2, updated_at = now() WHERE id = $3 RETURNING *`,
      [status, req.user.id, req.params.id]
    );
    if (result.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Loan not found' });
    }
    const loan = result.rows[0];

    await client.query(
      `INSERT INTO loan_status_history (loan_id, status, changed_by, comment) VALUES ($1,$2,$3,$4)`,
      [loan.id, status, req.user.id, comment || null]
    );

    const statusLabels = {
      submitted: 'Submitted',
      under_review: 'Under Review',
      documents_verified: 'Documents Verified',
      approved: 'Approved',
      rejected: 'Rejected',
      disbursed: 'Disbursed',
    };

    await client.query(
      `INSERT INTO notifications (user_id, title, message) VALUES ($1,$2,$3)`,
      [
        loan.client_id,
        'Loan Status Updated',
        `Your loan application status changed to "${statusLabels[status]}".${comment ? ' Note: ' + comment : ''}`,
      ]
    );

    await client.query('COMMIT');
    res.json(loan);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Could not update status' });
  } finally {
    client.release();
  }
});

module.exports = router;
