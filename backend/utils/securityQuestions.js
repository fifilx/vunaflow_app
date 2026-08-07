/**
 * Fixed list of security questions a client picks two of at registration.
 * Kept server-side so the same list is always the source of truth; the
 * Flutter app fetches this via GET /api/auth/security-question-options.
 */
const SECURITY_QUESTIONS = [
  'What is the name of your first pet?',
  "What is your mother's maiden name?",
  'What was the name of your primary school?',
  'What is your favorite childhood food?',
  'What city or town were you born in?',
  'What was the name of your best friend growing up?',
];

/** Normalizes an answer for consistent, forgiving comparison (case/whitespace-insensitive). */
function normalizeAnswer(answer) {
  return String(answer || '').trim().toLowerCase();
}

module.exports = { SECURITY_QUESTIONS, normalizeAnswer };
