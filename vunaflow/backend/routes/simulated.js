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
    if (isGreeting(message)) {
      const greetingReply =
        lang === 'sw'
          ? 'Habari! Mimi ni Msaidizi wa VunaFlow. Ninaweza kukusaidiaje leo? Unaweza kuniuliza kuhusu kuomba mkopo, hati zinazohitajika, viwango vya riba, na zaidi.'
          : "Hello! I'm the VunaFlow Assistant. How can I help you today? You can ask me about applying for a loan, required documents, interest rates, and more.";
      return res.json({ answer: greetingReply, matched_question: null });
    }

    const faqs = await pool.query('SELECT * FROM faqs');
    const text = message.toLowerCase();
    const match = faqs.rows.find(
      (f) =>
        text.includes(f.keyword.toLowerCase()) ||
        (f.keyword_sw && text.includes(f.keyword_sw.toLowerCase()))
    );

    if (match) {
      const answer = lang === 'sw' && match.answer_sw ? match.answer_sw : match.answer;
      const matched_question = lang === 'sw' && match.question_sw ? match.question_sw : match.question;
      return res.json({ answer, matched_question });
    }

    const fallback =
      lang === 'sw'
        ? 'Sijui kuhusu hilo bado. Jaribu kuuliza kuhusu jinsi ya kuomba, hati zinazohitajika, viwango vya riba, kiwango cha chini cha mkopo, sifa, ufuatiliaji wa maombi, au tawi. Unaweza pia kutembelea tawi lako la karibu la AFC kwa msaada zaidi.'
        : "I'm not sure about that yet. Try asking about how to apply, required documents, interest rates, minimum loan amount, eligibility, tracking your application, or choosing a branch. You can also visit your nearest AFC branch for further help.";

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
