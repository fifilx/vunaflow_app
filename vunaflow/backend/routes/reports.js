const express = require('express');
const pool = require('../config/db');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate, authorize('staff', 'admin'));

// GET /api/reports/summary - headline numbers
router.get('/summary', async (req, res) => {
  try {
    const [total, pending, approved, rejected, disbursed, clients] = await Promise.all([
      pool.query('SELECT COUNT(*) FROM loan_applications'),
      pool.query(
        "SELECT COUNT(*) FROM loan_applications WHERE status IN ('submitted','under_review','documents_verified')"
      ),
      pool.query("SELECT COUNT(*) FROM loan_applications WHERE status = 'approved'"),
      pool.query("SELECT COUNT(*) FROM loan_applications WHERE status = 'rejected'"),
      pool.query("SELECT COUNT(*) FROM loan_applications WHERE status = 'disbursed'"),
      pool.query("SELECT COUNT(*) FROM users WHERE role = 'client'"),
    ]);

    res.json({
      total_loans: Number(total.rows[0].count),
      pending_loans: Number(pending.rows[0].count),
      approved_loans: Number(approved.rows[0].count),
      rejected_loans: Number(rejected.rows[0].count),
      disbursed_loans: Number(disbursed.rows[0].count),
      total_clients: Number(clients.rows[0].count),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not generate summary report' });
  }
});

// GET /api/reports/analytics - data for charts
router.get('/analytics', async (req, res) => {
  try {
    const byMonth = await pool.query(`
      SELECT to_char(date_trunc('month', created_at), 'YYYY-MM') AS month, COUNT(*) AS count
      FROM loan_applications
      GROUP BY 1 ORDER BY 1 ASC
      LIMIT 12
    `);

    const approvedVsRejected = await pool.query(`
      SELECT status, COUNT(*) AS count
      FROM loan_applications
      WHERE status IN ('approved','rejected')
      GROUP BY status
    `);

    const amountStats = await pool.query(`
      SELECT
        COALESCE(SUM(amount_requested),0) AS total_amount,
        COALESCE(AVG(amount_requested),0) AS average_amount,
        COALESCE(MIN(amount_requested),0) AS min_amount,
        COALESCE(MAX(amount_requested),0) AS max_amount
      FROM loan_applications
    `);

    const byBranch = await pool.query(`
      SELECT b.name AS branch, COUNT(l.id) AS count
      FROM branches b LEFT JOIN loan_applications l ON l.branch_id = b.id
      GROUP BY b.name ORDER BY count DESC
    `);

    const byStatus = await pool.query(`
      SELECT status, COUNT(*) AS count FROM loan_applications GROUP BY status
    `);

    res.json({
      applications_by_month: byMonth.rows,
      approved_vs_rejected: approvedVsRejected.rows,
      loan_amounts: amountStats.rows[0],
      applications_by_branch: byBranch.rows,
      applications_by_status: byStatus.rows,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not generate analytics' });
  }
});

module.exports = router;
