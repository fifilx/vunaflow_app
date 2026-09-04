const express = require('express');
const pool = require('../config/db');

const router = express.Router();

const GREETINGS_EN = ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening', 'howdy'];
const GREETINGS_SW = ['habari', 'mambo', 'vipi', 'sasa', 'niaje', 'salamu', 'hujambo'];

function isGreeting(text) {
  const normalized = text.toLowerCase().trim();
  return [...GREETINGS_EN, ...GREETINGS_SW].some(
    (g) => normalized === g || normalized.startsWith(g + ' ') || normalized.startsWith(g + ',') || normalized.startsWith(g + '!')
  );
}

/**
 * POST /api/assistant/ask
 * Body: { message, lang } where lang is 'en' or 'sw' (defaults to 'en').
 * A simple bilingual FAQ chatbot: greets the user back on a greeting,
 * otherwise matches keywords in the faqs table (checking both the English
 * and Swahili keyword columns so either language of typed message works
 * regardless of the selected UI language).
 * No external AI integration required — swap this handler for a real
 * LLM API call later if desired (see anthropic_api_in_artifacts pattern).
 */
router.post('/assistant/ask', async (req, res) => {
  const { message } = req.body;
  const lang = req.body.lang === 'sw' ? 'sw' : 'en';
  if (!message || !message.trim()) return res.status(400).json({ error: 'message is required' });

  try {
    const rawText = message.toLowerCase().trim();

    if (isGreeting(message)) {
      const greetingReply =
        lang === 'sw'
          ? 'Habari! Mimi ni Msaidizi wa VunaFlow. Ninaweza kukusaidia kuhusu mikopo ya kilimo na mifugo, mahitaji ya hati, hesabu za riba na marejesho, au kuangalia hali ya mkopo wako. Nani nikusaidie na nini?'
          : "Hello! I'm your VunaFlow AI Assistant. I can help you with agricultural & livestock credit, document requirements, interest calculations, or checking eligibility. How may I assist you today?";
      return res.json({ answer: greetingReply, matched_question: null });
    }

    // 1. Detect 1 shilling / low amount queries
    if (rawText.includes('1 bob') || rawText.includes('1 shilling') || rawText.includes('1 ksh') || rawText.includes('ksh 1') || rawText.includes('shilling 1') || rawText.includes('500') || rawText.includes('1000')) {
      const reply = lang === 'sw'
        ? 'Mikopo ya kilimo ya VunaFlow inaanzia kiwango cha chini cha KSh 100,000 hadi KSh 1,000,000. Maombi ya chini ya KSh 100,000 (kama vile KSh 1 au KSh 50,000) hayakidhi kiwango cha chini cha mkopo wa kilimo wa VunaFlow.'
        : 'VunaFlow agricultural & livestock loans range from a minimum of KSh 100,000 to a maximum of KSh 1,000,000. Requests under KSh 100,000 do not meet agricultural financing thresholds. Please apply for KSh 100,000 or above.';
      return res.json({ answer: reply, matched_question: 'Minimum Loan Limit' });
    }

    // 2. Detect calculation / repayment schedule intent with numbers
    const numMatches = rawText.match(/(\d[\d,]*)/g);
    if (numMatches && (rawText.includes('interest') || rawText.includes('repay') || rawText.includes('pay') || rawText.includes('calculate') || rawText.includes('riba') || rawText.includes('lipa') || rawText.includes('hesabu'))) {
      const parsedVal = parseFloat(numMatches[0].replace(/,/g, ''));
      if (parsedVal >= 100000) {
        const annualRate = 0.12;
        const totalWithInterest = parsedVal * (1 + annualRate);
        const monthly12 = (totalWithInterest / 12).toFixed(0);
        const monthly6 = (parsedVal * (1 + 0.06) / 6).toFixed(0);

        const reply = lang === 'sw'
          ? `Kwa mkopo wa KSh ${parsedVal.toLocaleString()}:
• Riba ya Mwaka: 12% p.a. (1% kwa mwezi)
• Marejesho ya miezi 6: takriban KSh ${parseInt(monthly6).toLocaleString()} kwa mwezi
• Marejesho ya miezi 12: takriban KSh ${parseInt(monthly12).toLocaleString()} kwa mwezi (Jumla: KSh ${parseInt(totalWithInterest).toLocaleString()}).`
          : `For a loan of KSh ${parsedVal.toLocaleString()}:
• Interest Rate: 12% p.a. (1% per month)
• 6-Month Tenure: approx KSh ${parseInt(monthly6).toLocaleString()}/month
• 12-Month Tenure: approx KSh ${parseInt(monthly12).toLocaleString()}/month (Total Repayment: KSh ${parseInt(totalWithInterest).toLocaleString()}).`;

        return res.json({ answer: reply, matched_question: 'Loan Calculation' });
      }
    }

    // 3. Detect eligibility queries
    if (rawText.includes('eligible') || rawText.includes('eligibility') || rawText.includes('qualify') || rawText.includes('sifa') || rawText.includes('stahiki')) {
      const reply = lang === 'sw'
        ? 'Sifa za kupata mkopo wa VunaFlow: 1) Umri kuanzia miaka 18+. 2) Mkopo uwe KSh 100,000 hadi KSh 1,000,000. 3) Ukubwa wa shamba kuanzia ekari 2 au umiliki wa mifugo. 4) Hati halali ya ardhini/mkataba au dhamana.'
        : 'VunaFlow Eligibility Criteria: 1) Age 18 or older. 2) Loan amount between KSh 100,000 and KSh 1,000,000. 3) Minimum 2 acres of farmland or verified livestock ownership. 4) Valid National ID/KRA Pin and land title/lease or collateral document.';
      return res.json({ answer: reply, matched_question: 'Loan Eligibility Criteria' });
    }

    // 4. Database FAQ match fallback
    const faqs = await pool.query('SELECT * FROM faqs');
    const match = faqs.rows.find(
      (f) =>
        rawText.includes(f.keyword.toLowerCase()) ||
        (f.keyword_sw && rawText.includes(f.keyword_sw.toLowerCase()))
    );

    if (match) {
      const answer = lang === 'sw' && match.answer_sw ? match.answer_sw : match.answer;
      const matched_question = lang === 'sw' && match.question_sw ? match.question_sw : match.question;
      return res.json({ answer, matched_question });
    }

    const fallback =
      lang === 'sw'
        ? 'Ninawezaje kukusaidia vizuri zaidi? Jaribu kuuliza kuhusu: 1) Jinsi ya kuomba mkopo. 2) Sifa na kiwango cha chini (KSh 1,000). 3) Hesabu ya marejesho. 4) Hati zinazohitajika kama vile kitambulisho au hati ya shamba.'
        : "How can I better assist you? You can ask about: 1) How to apply for a loan. 2) Eligibility and minimum limits (KSh 1,000). 3) Repayment and interest calculations. 4) Required documents (ID, Land title/lease).";

    res.json({ answer: fallback, matched_question: null });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Assistant is unavailable right now' });
  }
});

// GET /api/assistant/faqs?lang=sw - list all predefined FAQs (used to render suggestion chips)
router.get('/assistant/faqs', async (req, res) => {
  const lang = req.query.lang === 'sw' ? 'sw' : 'en';
  try {
    const result = await pool.query('SELECT id, question, question_sw FROM faqs ORDER BY question ASC');
    const data = result.rows.map((r) => ({
      id: r.id,
      question: lang === 'sw' && r.question_sw ? r.question_sw : r.question,
    }));
    res.json(data);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not fetch FAQs' });
  }
});

// GET /api/farming-advice?crop=Maize
router.get('/farming-advice', async (req, res) => {
  try {
    if (req.query.crop) {
      const result = await pool.query('SELECT * FROM farming_advice WHERE crop ILIKE $1', [req.query.crop]);
      return res.json(result.rows);
    }
    const result = await pool.query('SELECT * FROM farming_advice ORDER BY crop ASC');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not fetch farming advice' });
  }
});

module.exports = router;
