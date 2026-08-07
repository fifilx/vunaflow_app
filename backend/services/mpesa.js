/**
 * mpesa.js — VunaFlow M-Pesa Daraja Sandbox Integration
 *
 * Implements:
 *  • OAuth 2.0 token generation (client credentials)
 *  • Lipa na M-Pesa Online (STK Push)
 *  • STK Push query (check transaction status)
 *
 * Safaricom Sandbox base URL: https://sandbox.safaricom.co.ke
 * Credentials are loaded from .env
 */

'use strict';

const axios = require('axios');

const BASE_URL =
  process.env.MPESA_ENV === 'production'
    ? 'https://api.safaricom.co.ke'
    : 'https://sandbox.safaricom.co.ke';

const CONSUMER_KEY    = process.env.MPESA_CONSUMER_KEY;
const CONSUMER_SECRET = process.env.MPESA_CONSUMER_SECRET;
const SHORTCODE       = process.env.MPESA_SHORTCODE  || '174379';
const PASSKEY         = process.env.MPESA_PASSKEY;
const CALLBACK_URL    = process.env.MPESA_CALLBACK_URL;

// --------------------------------------------------------------------------
// In-memory token cache so we don't hammer the OAuth endpoint
// --------------------------------------------------------------------------
let _cachedToken     = null;
let _tokenExpiresAt  = 0;

/**
 * getAccessToken()
 * Fetches an OAuth bearer token from Safaricom. Caches it until 30s before expiry.
 * @returns {Promise<string>} Bearer token
 */
async function getAccessToken() {
  if (_cachedToken && Date.now() < _tokenExpiresAt) {
    return _cachedToken;
  }

  const credentials = Buffer.from(`${CONSUMER_KEY}:${CONSUMER_SECRET}`).toString('base64');

  const response = await axios.get(
    `${BASE_URL}/oauth/v1/generate?grant_type=client_credentials`,
    {
      headers: { Authorization: `Basic ${credentials}` },
      timeout: 10_000,
    }
  );

  const { access_token, expires_in } = response.data;
  _cachedToken    = access_token;
  _tokenExpiresAt = Date.now() + (Number(expires_in) - 30) * 1000;

  return _cachedToken;
}

/**
 * generatePassword()
 * The STK Push password is base64(BusinessShortCode + Passkey + Timestamp).
 * @param {string} timestamp  Format: YYYYMMDDHHmmss
 * @returns {string} base64 password
 */
function generatePassword(timestamp) {
  const raw = `${SHORTCODE}${PASSKEY}${timestamp}`;
  return Buffer.from(raw).toString('base64');
}

/**
 * getTimestamp()
 * Returns current EAT time formatted as YYYYMMDDHHmmss (required by Safaricom).
 * @returns {string}
 */
function getTimestamp() {
  const now = new Date();
  const pad  = (n) => String(n).padStart(2, '0');
  return (
    now.getFullYear().toString() +
    pad(now.getMonth() + 1) +
    pad(now.getDate()) +
    pad(now.getHours()) +
    pad(now.getMinutes()) +
    pad(now.getSeconds())
  );
}

/**
 * stkPush({ phone, amount, accountRef, description })
 *
 * Initiates a Lipa na M-Pesa Online (STK Push) request.
 * On success the customer receives a PIN prompt on their phone.
 *
 * @param {object} opts
 * @param {string} opts.phone       - Customer MSISDN e.g. "254712345678"
 * @param {number} opts.amount      - Integer KSh amount (min 1)
 * @param {string} opts.accountRef  - Account reference shown on the M-Pesa receipt (max 12 chars)
 * @param {string} [opts.description] - Transaction description (max 13 chars)
 *
 * @returns {Promise<object>} Safaricom STK response containing MerchantRequestID, CheckoutRequestID, etc.
 */
async function stkPush({ phone, amount, accountRef, description = 'Loan repayment' }) {
  const token     = await getAccessToken();
  const timestamp = getTimestamp();
  const password  = generatePassword(timestamp);

  // Normalise phone: strip leading 0 and prepend 254
  const normalised = normalisePhone(phone);

  const payload = {
    BusinessShortCode: SHORTCODE,
    Password          : password,
    Timestamp         : timestamp,
    TransactionType   : 'CustomerPayBillOnline',
    Amount            : Math.round(amount),          // must be whole number
    PartyA            : normalised,                  // customer's phone
    PartyB            : SHORTCODE,                   // business receiving
    PhoneNumber       : normalised,                  // STK prompt goes here
    CallBackURL       : CALLBACK_URL,
    AccountReference  : accountRef.substring(0, 12), // shown on receipt
    TransactionDesc   : description.substring(0, 13),
  };

  const response = await axios.post(
    `${BASE_URL}/mpesa/stkpush/v1/processrequest`,
    payload,
    {
      headers: {
        Authorization : `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      timeout: 30_000,
    }
  );

  return response.data;
}

/**
 * querySTKStatus(checkoutRequestId)
 *
 * Query the status of an STK Push transaction.
 * ResultCode 0 = success, 1032 = cancelled by user, etc.
 *
 * @param {string} checkoutRequestId  - CheckoutRequestID returned from stkPush()
 * @returns {Promise<object>}
 */
async function querySTKStatus(checkoutRequestId) {
  const token     = await getAccessToken();
  const timestamp = getTimestamp();
  const password  = generatePassword(timestamp);

  const response = await axios.post(
    `${BASE_URL}/mpesa/stkpushquery/v1/query`,
    {
      BusinessShortCode: SHORTCODE,
      Password          : password,
      Timestamp         : timestamp,
      CheckoutRequestID : checkoutRequestId,
    },
    {
      headers: {
        Authorization : `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      timeout: 15_000,
    }
  );

  return response.data;
}

/**
 * normalisePhone(phone)
 * Accepts: 0712345678 / +254712345678 / 254712345678
 * Returns: 254712345678
 */
function normalisePhone(phone) {
  const str = String(phone).replace(/\s+/g, '').replace('+', '');
  if (str.startsWith('254')) return str;
  if (str.startsWith('0'))   return '254' + str.slice(1);
  return '254' + str;
}

/**
 * parseCallback(body)
 *
 * Parses the raw Safaricom STK callback body and returns a clean object.
 * Call this from your POST /api/loans/mpesa/callback route.
 *
 * @param {object} body - req.body from Safaricom
 * @returns {{ success: boolean, resultCode: number, resultDesc: string,
 *             merchantRequestId: string, checkoutRequestId: string,
 *             amount?: number, mpesaReceiptNumber?: string, phone?: string }}
 */
function parseCallback(body) {
  try {
    const stkCallback = body?.Body?.stkCallback ?? {};
    const resultCode  = stkCallback.ResultCode;
    const resultDesc  = stkCallback.ResultDesc;
    const merchantId  = stkCallback.MerchantRequestID;
    const checkoutId  = stkCallback.CheckoutRequestID;

    if (resultCode !== 0) {
      return { success: false, resultCode, resultDesc, merchantRequestId: merchantId, checkoutRequestId: checkoutId };
    }

    // Extract CallbackMetadata items
    const items = stkCallback.CallbackMetadata?.Item ?? [];
    const get   = (name) => items.find((i) => i.Name === name)?.Value;

    return {
      success             : true,
      resultCode,
      resultDesc,
      merchantRequestId   : merchantId,
      checkoutRequestId   : checkoutId,
      amount              : get('Amount'),
      mpesaReceiptNumber  : get('MpesaReceiptNumber'),
      transactionDate     : get('TransactionDate'),
      phone               : get('PhoneNumber'),
    };
  } catch {
    return { success: false, resultCode: -1, resultDesc: 'Failed to parse callback' };
  }
}

/**
 * simulateC2B({ shortCode, amount, msisdn, billRefNumber })
 *
 * Uses Safaricom's sandbox C2B simulate endpoint to force-complete a payment.
 * Only works in sandbox. Use this to test payment flows without a real phone.
 *
 * CommandID options: 'CustomerPayBillOnline' | 'CustomerBuyGoodsOnline'
 */
async function simulateC2B({ shortCode, amount, msisdn, billRefNumber = 'TEST', commandId = 'CustomerPayBillOnline' }) {
  const token = await getAccessToken();
  const response = await axios.post(
    `${BASE_URL}/mpesa/c2b/v1/simulate`,
    {
      ShortCode    : shortCode || SHORTCODE,
      CommandID    : commandId,
      Amount       : Math.round(amount),
      Msisdn       : normalisePhone(msisdn),
      BillRefNumber: billRefNumber,
    },
    {
      headers: {
        Authorization : `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      timeout: 15_000,
    }
  );
  return response.data;
}

/**
 * registerC2BUrls({ confirmationUrl, validationUrl })
 *
 * Registers C2B confirmation and validation URLs with Safaricom.
 * Must be called at least once before receiving C2B callbacks.
 */
async function registerC2BUrls({ confirmationUrl, validationUrl }) {
  const token = await getAccessToken();
  const response = await axios.post(
    `${BASE_URL}/mpesa/c2b/v1/registerurl`,
    {
      ShortCode      : SHORTCODE,
      ResponseType   : 'Completed',
      ConfirmationURL: confirmationUrl,
      ValidationURL  : validationUrl,
    },
    {
      headers: {
        Authorization : `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      timeout: 15_000,
    }
  );
  return response.data;
}

/**
 * reverseTransaction({ transactionId, amount, remarks })
 *
 * Initiates an M-Pesa Transaction Reversal.
 * https://sandbox.safaricom.co.ke/mpesa/reversal/v1/request
 */
async function reverseTransaction({ transactionId, amount, remarks = 'Reversal Request' }) {
  const token = await getAccessToken();
  const payload = {
    Initiator: 'testapi',
    SecurityCredential: 'MockSecurityCredential123==', // In sandbox, this is fine
    CommandID: 'TransactionReversal',
    TransactionID: transactionId,
    Amount: Math.round(amount),
    ReceiverParty: SHORTCODE,
    RecieverIdentifierType: '4', // 4 for shortcode
    ResultURL: CALLBACK_URL ? CALLBACK_URL.replace('/mpesa/callback', '/mpesa/reversal/callback') : 'https://vunaflow.com/reversal/callback',
    QueueTimeOutURL: CALLBACK_URL ? CALLBACK_URL.replace('/mpesa/callback', '/mpesa/reversal/callback') : 'https://vunaflow.com/reversal/callback',
    Remarks: remarks.substring(0, 100),
    Occasion: 'Reversal'
  };

  const response = await axios.post(
    `${BASE_URL}/mpesa/reversal/v1/request`,
    payload,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      timeout: 15_000,
    }
  );

  return response.data;
}

module.exports = { getAccessToken, stkPush, querySTKStatus, normalisePhone, parseCallback, simulateC2B, registerC2BUrls, reverseTransaction };
