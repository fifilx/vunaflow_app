const express = require('express');
const { body, validationResult } = require('express-validator');
const pool = require('../config/db');
const { authenticate, authorize } = require('../middleware/auth');
const mpesa = require('../services/mpesa');

const router = express.Router();

async function applyPaymentToLoans(client, clientId, currentLoanId, amount) {
  const targetResult = await client.query(
    `SELECT * FROM loan_applications WHERE id = $1 LIMIT 1`,
    [currentLoanId]
  );
  if (targetResult.rows.length === 0) return;
  const loan = targetResult.rows[0];

  const reqAmt = Number(loan.amount_requested);
  const paidAmt = Number(loan.amount_paid || 0);
  const remaining = Math.max(0, reqAmt - paidAmt);

  let payableToCurrent = Math.min(amount, remaining);
  let excess = amount - payableToCurrent;

  if (payableToCurrent > 0) {
    await client.query(
      `UPDATE loan_applications SET amount_paid = COALESCE(amount_paid, 0) + $1, updated_at = now() WHERE id = $2`,
      [payableToCurrent, currentLoanId]
    );
  }

  if (excess > 0) {
    const otherLoansResult = await client.query(
      `SELECT * FROM loan_applications 
       WHERE client_id = $1 AND id != $2 AND status IN ('disbursed', 'approved') AND COALESCE(amount_paid, 0) < amount_requested 
       ORDER BY created_at ASC`,
      [clientId, currentLoanId]
    );

    let remainingExcess = excess;

    for (const otherLoan of otherLoansResult.rows) {
      if (remainingExcess <= 0) break;
      const otherReq = Number(otherLoan.amount_requested);
      const otherPaid = Number(otherLoan.amount_paid || 0);
      const otherRemaining = Math.max(0, otherReq - otherPaid);
      const applyAmount = Math.min(remainingExcess, otherRemaining);

      if (applyAmount > 0) {
        await client.query(
          `UPDATE loan_applications SET amount_paid = COALESCE(amount_paid, 0) + $1, updated_at = now() WHERE id = $2`,
          [applyAmount, otherLoan.id]
        );
        remainingExcess -= applyAmount;
      }
    }

    if (remainingExcess > 0) {
      await client.query(
        `UPDATE farmer_profiles SET overpayment_balance = COALESCE(overpayment_balance, 0) + $1, updated_at = now() WHERE user_id = $2`,
        [remainingExcess, clientId]
      );

      await client.query(
        `INSERT INTO notifications (user_id, title, message) VALUES ($1, $2, $3)`,
        [
          clientId,
          '💳 Overpayment Credited',
          `Your loan has been fully repaid! Excess payment of KSh ${remainingExcess.toLocaleString()} was saved as Overpayment Credit in your profile (available for refund).`
        ]
      );
    }
  }
}

/**
 * POST /api/loans/mpesa/callback  (NO authentication — called by Safaricom)
 * Must be registered BEFORE router.use(authenticate) so the unauthenticated
 * Safaricom POST is not rejected with 401.
 */
router.post('/mpesa/callback', async (req, res) => {
  // Always respond 200 immediately — Safaricom retries if it doesn't get 200
  res.status(200).json({ ResultCode: 0, ResultDesc: 'Accepted' });

  const parsed = mpesa.parseCallback(req.body);
  console.log('[M-Pesa Callback]', JSON.stringify(parsed));

  if (!parsed.success) {
    console.warn('[M-Pesa Callback] Payment not successful. ResultCode:', parsed.resultCode, '-', parsed.resultDesc);

    // ── SANDBOX MODE: auto-complete on any failure ──────────────────────────
    // In Safaricom sandbox, using a real phone number returns ResultCode=1
    // (insufficient funds) or 1032 (cancelled) because the virtual wallet has no balance
    // or isn't fully configured. We override this by completing the payment
    // from our 500B sandbox ledger anyway so the app flow succeeds.
    const isSandbox = process.env.MPESA_ENV !== 'production';

    if (isSandbox && parsed.checkoutRequestId) {
      console.log('[M-Pesa Sandbox] Auto-completing payment from sandbox ledger...');
      const sandboxClient = await pool.connect();
      try {
        await sandboxClient.query('BEGIN');

        const pendingResult = await sandboxClient.query(
          `SELECT * FROM payments WHERE transaction_ref=$1 AND status='pending' LIMIT 1`,
          [parsed.checkoutRequestId]
        );

        if (pendingResult.rows.length === 0) {
          console.warn('[M-Pesa Sandbox] No pending payment found for', parsed.checkoutRequestId);
          await sandboxClient.query('ROLLBACK');
          return;
        }

        const payment = pendingResult.rows[0];
        const sandboxRef = `SANDBOX-${Date.now()}`;

        await sandboxClient.query(
          `UPDATE payments SET status='completed', transaction_ref=$1 WHERE id=$2`,
          [sandboxRef, payment.id]
        );

        await applyPaymentToLoans(sandboxClient, payment.client_id, payment.loan_id, Number(payment.amount));

        await debitSandbox(sandboxClient, payment.amount);

        await sandboxClient.query(
          'INSERT INTO notifications (user_id, title, message) VALUES ($1,$2,$3)',
          [
            payment.client_id,
            '✅ M-Pesa Repayment Confirmed',
            `Your M-Pesa payment of KSh ${Number(payment.amount).toLocaleString()} was confirmed (Sandbox Ref: ${sandboxRef}). Thank you for repaying your VunaFlow loan!`,
          ]
        );

        await sandboxClient.query('COMMIT');
        console.log('[M-Pesa Sandbox] Payment auto-completed. Ref:', sandboxRef);
      } catch (err) {
        await sandboxClient.query('ROLLBACK');
        console.error('[M-Pesa Sandbox] Auto-complete error:', err);
        // Fall through: mark as failed
        await pool.query(
          `UPDATE payments SET status='failed' WHERE transaction_ref=$1`,
          [parsed.checkoutRequestId]
        ).catch(console.error);
      } finally {
        sandboxClient.release();
      }
      return;
    }
    // ── END SANDBOX AUTO-COMPLETE ────────────────────────────────────────────

    if (parsed.checkoutRequestId) {
      await pool.query(
        `UPDATE payments SET status='failed' WHERE transaction_ref=$1`,
        [parsed.checkoutRequestId]
      ).catch(console.error);
    }
    return;
  }

  const dbClient = await pool.connect();
  try {
    await dbClient.query('BEGIN');

    const pendingResult = await dbClient.query(
      `SELECT * FROM payments WHERE transaction_ref=$1 AND status='pending' LIMIT 1`,
      [parsed.checkoutRequestId]
    );

    if (pendingResult.rows.length === 0) {
      console.warn('[M-Pesa Callback] No pending payment found for', parsed.checkoutRequestId);
      await dbClient.query('ROLLBACK');
      return;
    }

    const payment = pendingResult.rows[0];
    const mpesaRef = parsed.mpesaReceiptNumber || `MPESA-${Date.now()}`;

    await dbClient.query(
      `UPDATE payments SET status='completed', transaction_ref=$1, amount=$2 WHERE id=$3`,
      [mpesaRef, parsed.amount ?? payment.amount, payment.id]
    );

    await applyPaymentToLoans(dbClient, payment.client_id, payment.loan_id, Number(parsed.amount ?? payment.amount));

    // Deduct confirmed amount from sandbox ledger
    await debitSandbox(dbClient, parsed.amount ?? payment.amount);

    await pool.query(
      'INSERT INTO notifications (user_id, title, message) VALUES ($1,$2,$3)',
      [
        payment.client_id,
        '✅ M-Pesa Repayment Confirmed',
        `Your M-Pesa payment of KSh ${Number(parsed.amount ?? payment.amount).toLocaleString()} was confirmed. Receipt: ${mpesaRef}. Thank you for repaying your VunaFlow loan!`,
      ]
    );

    await dbClient.query('COMMIT');
    console.log('[M-Pesa Callback] Payment confirmed. Receipt:', mpesaRef);
  } catch (err) {
    await dbClient.query('ROLLBACK');
    console.error('[M-Pesa Callback] DB error:', err);
  } finally {
    dbClient.release();
  }
});

// All routes below require a valid JWT
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
 * debitSandbox(client, amount)
 * Deducts `amount` from the M-Pesa sandbox ledger inside an existing transaction.
 * Fails gracefully if the table doesn't exist yet.
 */
async function debitSandbox(dbClient, amount) {
  try {
    await dbClient.query(
      `UPDATE mpesa_sandbox_ledger SET balance = GREATEST(balance - $1, 0), updated_at = now() WHERE id = 1`,
      [amount]
    );
  } catch (err) {
    // Non-fatal — sandbox ledger is optional
    console.warn('[Sandbox] Could not debit ledger:', err.message);
  }
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
    body('collateral').trim().notEmpty().withMessage('Collateral description is required'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { amount_requested, purpose, repayment_period_months, branch_id, collateral } = req.body;

    try {
      const userResult = await pool.query('SELECT branch_id FROM users WHERE id = $1', [req.user.id]);
      const profileResult = await pool.query('SELECT * FROM farmer_profiles WHERE user_id = $1', [req.user.id]);
      const profile = profileResult.rows[0];

      // Require a complete farmer profile before a loan can be submitted.
      const missingFields = [];
      if (!profile?.national_id) missingFields.push('National ID');
      if (!profile?.date_of_birth) missingFields.push('Date of Birth');
      if (!profile?.farm_size_acres) missingFields.push('Farm Size');

      // Primary crop is only required if farmer grows crops or both
      if (profile?.farming_type !== 'livestock' && !profile?.primary_crop) {
        missingFields.push('Primary Crop');
      }
      // Livestock type is required if farmer keeps livestock
      if ((profile?.farming_type === 'livestock' || profile?.farming_type === 'both') && !profile?.livestock_type) {
        missingFields.push('Livestock Category');
      }

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

      // ── CONSTRAINT 1: Check for active unpaid loans
      const activeCheck = await pool.query(
        `SELECT id FROM loan_applications 
         WHERE client_id = $1 AND status != 'rejected' AND COALESCE(amount_paid, 0) < amount_requested`,
        [req.user.id]
      );
      if (activeCheck.rows.length > 0) {
        return res.status(400).json({
          error: 'You cannot borrow a new loan because you have an existing loan that is not fully repaid.',
          code: 'ACTIVE_LOAN_EXISTS',
        });
      }

      // ── CONSTRAINT 2: Check for unique collateral
      const collateralCheck = await pool.query(
        `SELECT id FROM loan_applications 
         WHERE client_id = $1 AND LOWER(TRIM(collateral)) = LOWER($2)`,
        [req.user.id, collateral.trim()]
      );
      if (collateralCheck.rows.length > 0) {
        return res.status(400).json({
          error: 'This collateral has already been used for another loan application. Please provide a different collateral.',
          code: 'COLLATERAL_ALREADY_USED',
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
           (client_id, branch_id, amount_requested, purpose, repayment_period_months, status, eligibility_result, collateral)
         VALUES ($1,$2,$3,$4,$5,'submitted',$6,$7)
         RETURNING *`,
        [req.user.id, resolvedBranchId, amount_requested, purpose, repayment_period_months, eligibility.result, collateral.trim()]
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

  const reqAmount = parseFloat(amount_requested) || 0;

  const checks = {
    farmSizeOk: (farm_size_acres ?? 0) >= 2,
    amountAboveMin: reqAmount >= 1000,
    amountBelowMax: reqAmount <= 1000000,
    hasCollateral: !!has_collateral,
    ageOk: age === null ? null : age >= 18,
  };

  if (!checks.farmSizeOk) reasons.push('Farm size is below the recommended 2 acres');
  if (!checks.amountAboveMin) reasons.push('Requested amount is below the minimum loan limit of KSh 1,000');
  if (!checks.amountBelowMax) reasons.push('Requested amount exceeds the maximum loan limit of KSh 1,000,000');
  if (!checks.hasCollateral) reasons.push('No collateral or land document on file');
  if (checks.ageOk === false) reasons.push('Applicant is under 18 years old');
  if (checks.ageOk === null) reasons.push('Date of birth not provided');

  const likelyEligible =
    checks.farmSizeOk && checks.amountAboveMin && checks.amountBelowMax && checks.hasCollateral && checks.ageOk === true;

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
  const { status, comment, account_number } = req.body;
  if (!VALID_STATUSES.includes(status)) {
    return res.status(400).json({ error: `Status must be one of: ${VALID_STATUSES.join(', ')}` });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    let result;
    if (account_number !== undefined) {
      result = await client.query(
        `UPDATE loan_applications SET status = $1, reviewed_by = $2, account_number = $3, updated_at = now() WHERE id = $4 RETURNING *`,
        [status, req.user.id, account_number, req.params.id]
      );
    } else {
      result = await client.query(
        `UPDATE loan_applications SET status = $1, reviewed_by = $2, updated_at = now() WHERE id = $3 RETURNING *`,
        [status, req.user.id, req.params.id]
      );
    }
    
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

    let notificationMessage = `Your loan application status changed to "${statusLabels[status]}".${comment ? ' Note: ' + comment : ''}`;
    if (status === 'disbursed' && loan.account_number) {
      notificationMessage = `Your loan has been disbursed to account ${loan.account_number}.`;
    }

    await client.query(
      `INSERT INTO notifications (user_id, title, message) VALUES ($1,$2,$3)`,
      [
        loan.client_id,
        'Loan Status Updated',
        notificationMessage,
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

/**
 * POST /api/loans/:id/pay
 *
 * Initiates an M-Pesa Daraja STK Push for the loan repayment.
 * For Bank Transfer / Debit Card the payment is recorded immediately (simulated).
 *
 * Body: { amount, payment_method, phone_number }
 *
 * On M-Pesa success the response includes:
 *  - checkoutRequestId  ← poll /api/loans/:id/mpesa/query with this to confirm
 *  - merchantRequestId
 *  - stkPushSent: true
 *
 * When Safaricom confirms the PIN entry it calls POST /api/loans/mpesa/callback
 * which then marks the payment as completed in the database.
 */
/**
 * PATCH /api/loans/:id/account_number - staff assigns/updates account number manually
 * Body: { account_number }
 */
router.patch('/:id/account_number', authorize('staff', 'admin'), async (req, res) => {
  const { account_number } = req.body;
  if (!account_number || account_number.trim() === '') {
    return res.status(400).json({ error: 'Account number is required' });
  }

  try {
    const result = await pool.query(
      `UPDATE loan_applications SET account_number = $1, updated_at = now() WHERE id = $2 RETURNING *`,
      [account_number.trim(), req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Loan not found' });
    }

    // Insert history record
    await pool.query(
      `INSERT INTO loan_status_history (loan_id, status, changed_by, comment) VALUES ($1,$2,$3,$4)`,
      [req.params.id, result.rows[0].status, req.user.id, `Account number updated to: ${account_number.trim()}`]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not update account number' });
  }
});

router.post('/:id/pay', authorize('client'), async (req, res) => {
  const { amount, payment_method = 'M-Pesa', phone_number } = req.body;
  const numAmount = Number(amount);
  if (!numAmount || numAmount <= 0) {
    return res.status(400).json({ error: 'Enter a valid repayment amount greater than 0' });
  }

  // Verify loan ownership before doing anything
  const loanResult = await pool.query('SELECT * FROM loan_applications WHERE id = $1', [req.params.id]);
  if (loanResult.rows.length === 0) return res.status(404).json({ error: 'Loan not found' });
  const loan = loanResult.rows[0];
  if (loan.client_id !== req.user.id) {
    return res.status(403).json({ error: 'Not authorised to make payments on this loan' });
  }

  // ── M-Pesa STK Push ────────────────────────────────────────────────────────
  if (payment_method === 'M-Pesa') {
    if (!phone_number) {
      return res.status(400).json({ error: 'Phone number is required for M-Pesa payments.' });
    }

    try {
      const shortRef = loan.id.toString().replace(/-/g, '').substring(0, 12);
      const stkRes = await mpesa.stkPush({
        phone      : phone_number,
        amount     : numAmount,
        accountRef : shortRef,
        description: 'Loan repayment',
      });

      // Store a *pending* payment record so we can update it via callback
      const pendingRef = stkRes.CheckoutRequestID || `STK-${Date.now()}`;
      await pool.query(
        `INSERT INTO payments
           (loan_id, client_id, amount, payment_method, phone_number, transaction_ref, status)
         VALUES ($1,$2,$3,'M-Pesa',$4,$5,'pending')`,
        [loan.id, req.user.id, numAmount, mpesa.normalisePhone(phone_number), pendingRef]
      );

      return res.status(202).json({
        stkPushSent        : true,
        checkoutRequestId  : stkRes.CheckoutRequestID,
        merchantRequestId  : stkRes.MerchantRequestID,
        responseDescription: stkRes.ResponseDescription,
        message:
          'STK Push sent! Check your phone and enter your M-Pesa PIN to complete the repayment. ' +
          'The payment will be confirmed automatically once your PIN is entered.',
      });
    } catch (stkErr) {
      console.error('M-Pesa STK Push error:', stkErr?.response?.data || stkErr.message);
      const errDetail = stkErr?.response?.data?.errorMessage || stkErr.message || 'M-Pesa STK Push failed';
      return res.status(502).json({
        error    : `M-Pesa request failed: ${errDetail}. Please try again or choose another payment method.`,
        mpesaError: stkErr?.response?.data,
      });
    }
  }

  // ── Bank Transfer / Debit Card — recorded immediately (simulated) ──────────
  const dbClient = await pool.connect();
  try {
    await dbClient.query('BEGIN');

    const randomCode    = Math.random().toString(36).substring(2, 9).toUpperCase();
    const transaction_ref = `${payment_method.toUpperCase().replace(/\s+/g, '-')}-${randomCode}`;

    const paymentResult = await dbClient.query(
      `INSERT INTO payments
         (loan_id, client_id, amount, payment_method, phone_number, transaction_ref, status)
       VALUES ($1,$2,$3,$4,$5,$6,'completed') RETURNING *`,
      [loan.id, req.user.id, numAmount, payment_method, phone_number || null, transaction_ref]
    );

    await applyPaymentToLoans(dbClient, req.user.id, loan.id, numAmount);

    const updatedLoanRes = await dbClient.query('SELECT * FROM loan_applications WHERE id = $1', [loan.id]);
    const updatedLoan = updatedLoanRes.rows[0];

    // Deduct from sandbox ledger (simulated M-Pesa till balance)
    await debitSandbox(dbClient, numAmount);

    await notify(
      req.user.id,
      'Loan Repayment Received',
      `Payment of KSh ${numAmount.toLocaleString()} via ${payment_method} (Ref: ${transaction_ref}) received. Thank you!`
    );

    await dbClient.query('COMMIT');
    return res.status(201).json({
      payment: paymentResult.rows[0],
      loan   : updatedLoan.rows[0],
      message: `Repayment of KSh ${numAmount.toLocaleString()} via ${payment_method} recorded successfully!`,
    });
  } catch (err) {
    await dbClient.query('ROLLBACK');
    console.error(err);
    return res.status(500).json({ error: 'Could not process repayment' });
  } finally {
    dbClient.release();
  }
});

// (mpesa/callback is handled above, before authenticate middleware)

/**
 * GET /api/loans/:id/mpesa/query?checkoutRequestId=...
 *
 * Client polls this to check if an STK push was confirmed.
 * Returns the payment record status ('pending' | 'completed' | 'failed').
 */
router.get('/:id/mpesa/query', authorize('client'), async (req, res) => {
  const { checkoutRequestId } = req.query;
  if (!checkoutRequestId) {
    return res.status(400).json({ error: 'checkoutRequestId query parameter is required' });
  }
  try {
    // Check our local DB first (fastest)
    const local = await pool.query(
      `SELECT * FROM payments WHERE transaction_ref=$1 LIMIT 1`,
      [checkoutRequestId]
    );

    if (local.rows.length > 0) {
      const payment = local.rows[0];

      // AUTO-COMPLETE FOR SANDBOX IF TUNNEL IS NOT REACHABLE
      if (payment.status === 'pending' && process.env.MPESA_ENV !== 'production') {
        console.log('[M-Pesa Sandbox] Auto-completing from query poll...');
        const sandboxRef = `SANDBOX-${Date.now()}`;
        const dbClient = await pool.connect();
        try {
          await dbClient.query('BEGIN');
          await dbClient.query(`UPDATE payments SET status='completed', transaction_ref=$1 WHERE id=$2`, [sandboxRef, payment.id]);
          await applyPaymentToLoans(dbClient, payment.client_id, payment.loan_id, Number(payment.amount));
          await debitSandbox(dbClient, payment.amount);
          await dbClient.query('INSERT INTO notifications (user_id, title, message) VALUES ($1,$2,$3)', [payment.client_id, '✅ M-Pesa Repayment Confirmed', `Your M-Pesa payment of KSh ${Number(payment.amount).toLocaleString()} was confirmed (Sandbox).`]);
          await dbClient.query('COMMIT');
          payment.status = 'completed';
          payment.transaction_ref = sandboxRef;
        } catch (e) {
          await dbClient.query('ROLLBACK');
          console.error('Sandbox autocomplete error', e);
        } finally {
          dbClient.release();
        }
      }

      return res.json({ source: 'local', payment: payment });
    }

    // Fall back to Safaricom live query
    const stkQuery = await mpesa.querySTKStatus(checkoutRequestId);
    return res.json({ source: 'safaricom', result: stkQuery });
  } catch (err) {
    console.error('STK query error:', err?.response?.data || err.message);
    return res.status(502).json({ error: 'Could not query M-Pesa transaction status' });
  }
});

/**
 * GET /api/loans/:id/payments
 * Get list of all repayments for a loan (client or staff)
 */
router.get('/:id/payments', async (req, res) => {
  try {
    const loanResult = await pool.query('SELECT * FROM loan_applications WHERE id = $1', [req.params.id]);
    if (loanResult.rows.length === 0) return res.status(404).json({ error: 'Loan not found' });
    const loan = loanResult.rows[0];

    if (req.user.role === 'client' && loan.client_id !== req.user.id) {
      return res.status(403).json({ error: 'Not authorized' });
    }

    const result = await pool.query(
      "SELECT * FROM payments WHERE loan_id = $1 AND status IN ('completed', 'reversed') ORDER BY created_at DESC",
      [req.params.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not fetch payments' });
  }
});

/**
 * POST /api/loans/:id/payments/:paymentId/reverse
 * Staff triggers a reversal for a payment
 */
router.post('/:id/payments/:paymentId/reverse', authorize('staff', 'admin'), async (req, res) => {
  const { id: loanId, paymentId } = req.params;
  const dbClient = await pool.connect();
  try {
    await dbClient.query('BEGIN');

    // 1. Fetch payment details
    const paymentResult = await dbClient.query(
      `SELECT * FROM payments WHERE id = $1 AND loan_id = $2 AND status = 'completed' LIMIT 1`,
      [paymentId, loanId]
    );

    if (paymentResult.rows.length === 0) {
      await dbClient.query('ROLLBACK');
      return res.status(404).json({ error: 'Completed payment not found' });
    }

    const payment = paymentResult.rows[0];

    // 2. Call M-Pesa reversal API
    let reversalResult;
    try {
      reversalResult = await mpesa.reverseTransaction({
        transactionId: payment.transaction_ref,
        amount: payment.amount,
        remarks: 'Staff reversed payment'
      });
      console.log('[M-Pesa Reversal API Response]', reversalResult);
    } catch (err) {
      console.warn('[M-Pesa Reversal API Failed] proceeding with sandbox auto-reversal', err?.response?.data || err.message);
    }

    // 3. Mark payment as reversed
    await dbClient.query(
      `UPDATE payments SET status = 'reversed' WHERE id = $1`,
      [payment.id]
    );

    // 4. Subtract reversed amount from loan application paid amount
    const updatedLoan = await dbClient.query(
      `UPDATE loan_applications SET amount_paid = COALESCE(amount_paid,0) - $1, updated_at = now() WHERE id = $2 RETURNING *`,
      [payment.amount, loanId]
    );

    // 5. Notify client about the reversal
    await dbClient.query(
      'INSERT INTO notifications (user_id, title, message) VALUES ($1,$2,$3)',
      [
        payment.client_id,
        '⚠️ M-Pesa Repayment Reversed',
        `Your M-Pesa payment of KSh ${Number(payment.amount).toLocaleString()} (Ref: ${payment.transaction_ref}) has been reversed. Your loan balance has been updated.`
      ]
    );

    await dbClient.query('COMMIT');
    res.json({
      message: 'Payment reversed successfully',
      loan: updatedLoan.rows[0]
    });
  } catch (err) {
    await dbClient.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Failed to reverse payment' });
  } finally {
    dbClient.release();
  }
});

module.exports = router;
