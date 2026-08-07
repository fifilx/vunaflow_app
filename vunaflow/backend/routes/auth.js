const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { body, validationResult } = require('express-validator');
const pool = require('../config/db');
const { normalizeKenyanPhone } = require('../utils/phone');
const { toTitleCase } = require('../utils/text');
const { SECURITY_QUESTIONS, normalizeAnswer } = require('../utils/securityQuestions');

const router = express.Router();

function signToken(user) {
  return jwt.sign(
    { id: user.id, role: user.role, email: user.email, full_name: user.full_name },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
}

// GET /api/auth/security-question-options - the fixed list a client picks two from at registration
router.get('/security-question-options', (req, res) => {
  res.json(SECURITY_QUESTIONS);
});

/**
 * POST /api/auth/register
 * Registers a client (farmer) account. Staff accounts are created by an admin
 * via /api/admin/staff instead, so the public registration form always
 * creates role = 'client'.
 *
 * Also collects two security questions + answers, used later for password
 * reset in place of an email/SMS code (which this build can't actually send).
 */
router.post(
  '/register',
  [
    body('full_name').trim().notEmpty().withMessage('Full name is required'),
    body('email').isEmail().withMessage('A valid email is required'),
    body('phone').trim().notEmpty().withMessage('Phone number is required'),
    body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
    body('confirm_password').custom((value, { req }) => {
      if (value !== req.body.password) throw new Error('Passwords do not match');
      return true;
    }),
    body('branch_id').optional({ nullable: true }).isUUID().withMessage('Invalid branch selected'),
    body('security_question_1').notEmpty().withMessage('Select your first security question'),
    body('security_answer_1').trim().isLength({ min: 2 }).withMessage('Answer 1 is too short'),
    body('security_question_2').notEmpty().withMessage('Select your second security question'),
    body('security_answer_2').trim().isLength({ min: 2 }).withMessage('Answer 2 is too short'),
    body('security_question_2').custom((value, { req }) => {
      if (value === req.body.security_question_1) throw new Error('Choose two different security questions');
      return true;
    }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const {
      full_name,
      email,
      password,
      branch_id,
      security_question_1,
      security_answer_1,
      security_question_2,
      security_answer_2,
    } = req.body;

    if (!SECURITY_QUESTIONS.includes(security_question_1) || !SECURITY_QUESTIONS.includes(security_question_2)) {
      return res.status(400).json({ error: 'Invalid security question selected' });
    }

    const normalizedPhone = normalizeKenyanPhone(req.body.phone);
    if (!normalizedPhone) {
      return res.status(400).json({
        error: 'Enter a valid Kenyan phone number, e.g. 0712345678, 0112345678, or +254712345678',
      });
    }
    const phone = normalizedPhone;

    try {
      const existing = await pool.query('SELECT id FROM users WHERE email = $1 OR phone = $2', [email, phone]);
      if (existing.rows.length > 0) {
        return res.status(409).json({ error: 'An account with this email or phone already exists' });
      }

      const password_hash = await bcrypt.hash(password, 10);
      const answer1Hash = await bcrypt.hash(normalizeAnswer(security_answer_1), 10);
      const answer2Hash = await bcrypt.hash(normalizeAnswer(security_answer_2), 10);

      const result = await pool.query(
        `INSERT INTO users
           (full_name, email, phone, password_hash, role, branch_id,
            security_question_1, security_answer_1_hash, security_question_2, security_answer_2_hash)
         VALUES ($1, $2, $3, $4, 'client', $5, $6, $7, $8, $9)
         RETURNING id, full_name, email, phone, role, branch_id, created_at`,
        [toTitleCase(full_name), email, phone, password_hash, branch_id || null, security_question_1, answer1Hash, security_question_2, answer2Hash]
      );
      const user = result.rows[0];

      // Create an empty farmer profile shell so /profile edit works immediately
      await pool.query('INSERT INTO farmer_profiles (user_id) VALUES ($1)', [user.id]);

      // Welcome notification
      await pool.query(
        `INSERT INTO notifications (user_id, title, message) VALUES ($1, $2, $3)`,
        [user.id, 'Welcome to VunaFlow', 'Your account has been created. Complete your farmer profile to get started with a loan application.']
      );

      const token = signToken(user);
      res.status(201).json({ token, user });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Registration failed. Please try again.' });
    }
  }
);

/**
 * POST /api/auth/login
 * Body: { email, password, portal: 'client' | 'staff' }
 * The portal field lets the frontend enforce separate Client/Staff login screens:
 * a client cannot log in through the staff portal and vice versa.
 */
router.post(
  '/login',
  [
    body('email').isEmail(),
    body('password').notEmpty(),
    body('portal').isIn(['client', 'staff']),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { email, password, portal } = req.body;

    try {
      const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
      if (result.rows.length === 0) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }
      const user = result.rows[0];

      if (!user.is_active) {
        return res.status(403).json({ error: 'This account has been disabled. Contact AFC support.' });
      }

      const portalMatches = portal === 'client' ? user.role === 'client' : ['staff', 'admin'].includes(user.role);
      if (!portalMatches) {
        return res.status(403).json({ error: `This account is not registered for the ${portal} portal` });
      }

      const valid = await bcrypt.compare(password, user.password_hash);
      if (!valid) return res.status(401).json({ error: 'Invalid email or password' });

      delete user.password_hash;
      const token = signToken(user);
      res.json({ token, user });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Login failed. Please try again.' });
    }
  }
);

/**
 * GET /api/auth/security-questions?email=...
 * Step 1 of password reset: returns the two security questions on file for
 * this email (not the answers), so the app can prompt for them.
 */
router.get('/security-questions', async (req, res) => {
  const email = (req.query.email || '').toString().trim();
  if (!email) return res.status(400).json({ error: 'email is required' });

  try {
    const result = await pool.query(
      'SELECT security_question_1, security_question_2 FROM users WHERE email = $1',
      [email]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'No account found with that email address' });
    }
    const { security_question_1, security_question_2 } = result.rows[0];
    if (!security_question_1 || !security_question_2) {
      return res.status(400).json({
        error: 'This account has no security questions on file. Please contact AFC support for help resetting your password.',
      });
    }
    res.json({ question_1: security_question_1, question_2: security_question_2 });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not fetch security questions' });
  }
});

/**
 * POST /api/auth/verify-security-answers
 * Step 2 of password reset: body { email, answer_1, answer_2 }.
 * If both answers match (case/whitespace-insensitive), issues a short-lived
 * reset token the app then uses to actually change the password.
 */
router.post(
  '/verify-security-answers',
  [body('email').isEmail(), body('answer_1').notEmpty(), body('answer_2').notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { email, answer_1, answer_2 } = req.body;
    try {
      const result = await pool.query(
        'SELECT id, security_answer_1_hash, security_answer_2_hash FROM users WHERE email = $1',
        [email]
      );
      if (result.rows.length === 0) return res.status(404).json({ error: 'No account found with that email address' });

      const user = result.rows[0];
      if (!user.security_answer_1_hash || !user.security_answer_2_hash) {
        return res.status(400).json({ error: 'This account has no security questions on file.' });
      }

      const match1 = await bcrypt.compare(normalizeAnswer(answer_1), user.security_answer_1_hash);
      const match2 = await bcrypt.compare(normalizeAnswer(answer_2), user.security_answer_2_hash);

      if (!match1 || !match2) {
        return res.status(401).json({ error: 'One or both answers are incorrect. Please try again.' });
      }

      const resetToken = crypto.randomBytes(20).toString('hex');
      const expires = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes
      await pool.query('UPDATE users SET reset_token = $1, reset_token_expires = $2 WHERE id = $3', [
        resetToken,
        expires,
        user.id,
      ]);

      res.json({ message: 'Identity verified.', reset_token: resetToken });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Could not verify security answers' });
    }
  }
);

/**
 * POST /api/auth/reset-password
 * Step 3 of password reset: body { email, reset_token, new_password }.
 * reset_token comes from a successful /verify-security-answers call.
 */
router.post(
  '/reset-password',
  [
    body('email').isEmail(),
    body('reset_token').notEmpty(),
    body('new_password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { email, reset_token, new_password } = req.body;
    try {
      const result = await pool.query(
        'SELECT id, reset_token, reset_token_expires FROM users WHERE email = $1',
        [email]
      );
      if (result.rows.length === 0) return res.status(400).json({ error: 'Invalid request' });

      const user = result.rows[0];
      if (!user.reset_token || user.reset_token !== reset_token || new Date() > new Date(user.reset_token_expires)) {
        return res.status(400).json({ error: 'This reset session has expired. Please verify your security answers again.' });
      }

      const password_hash = await bcrypt.hash(new_password, 10);
      await pool.query(
        'UPDATE users SET password_hash = $1, reset_token = NULL, reset_token_expires = NULL WHERE id = $2',
        [password_hash, user.id]
      );

      res.json({ message: 'Password has been reset successfully. You can now log in.' });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Could not reset password' });
    }
  }
);

module.exports = router;
