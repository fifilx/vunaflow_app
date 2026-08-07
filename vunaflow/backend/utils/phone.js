/**
 * Normalizes a Kenyan phone number to +254XXXXXXXXX format.
 * Accepts: 07XXXXXXXX, 01XXXXXXXX, 2547XXXXXXXX, 2541XXXXXXXX,
 *          +2547XXXXXXXX, +2541XXXXXXXX (spaces/dashes are stripped).
 * Returns the normalized +254... string, or null if the input doesn't
 * match a valid Kenyan mobile number shape (9 digits after the 254
 * country code, starting with 7 or 1 — matching Safaricom/Airtel/Telkom
 * numbering).
 */
function normalizeKenyanPhone(input) {
  if (!input) return null;
  let digits = String(input).replace(/[^\d+]/g, '');

  if (digits.startsWith('+254')) {
    digits = digits.slice(1);
  } else if (digits.startsWith('254')) {
    // already in country-code form
  } else if (digits.startsWith('0')) {
    digits = '254' + digits.slice(1);
  } else {
    return null;
  }

  if (!/^254[71]\d{8}$/.test(digits)) return null;
  return '+' + digits;
}

module.exports = { normalizeKenyanPhone };
