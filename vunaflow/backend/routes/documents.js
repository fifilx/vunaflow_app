const express = require('express');
const pool = require('../config/db');
const { authenticate, authorize } = require('../middleware/auth');
const upload = require('../middleware/upload');

const router = express.Router();
router.use(authenticate);

const VALID_TYPES = ['national_id', 'title_deed', 'collateral', 'other'];

/**
 * POST /api/documents
 * multipart/form-data: file, doc_type, loan_id (optional)
 */
router.post('/', authorize('client'), upload.single('file'), async (req, res) => {
  const { doc_type, loan_id } = req.body;
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  if (!VALID_TYPES.includes(doc_type)) {
    return res.status(400).json({ error: `doc_type must be one of: ${VALID_TYPES.join(', ')}` });
  }

  try {
    const filePath = `${process.env.UPLOAD_DIR || 'uploads'}/${req.file.filename}`;
    const result = await pool.query(
      `INSERT INTO documents (loan_id, client_id, doc_type, file_path, original_filename)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [loan_id || null, req.user.id, doc_type, filePath, req.file.originalname]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not save document' });
  }
});

// GET /api/documents/mine?loan_id=... - documents uploaded by the client,
// optionally scoped to one loan application (used by the document upload
// screen so documents from a different, earlier loan don't get mixed in).
router.get('/mine', authorize('client'), async (req, res) => {
  try {
    const { loan_id } = req.query;
    const result = loan_id
      ? await pool.query('SELECT * FROM documents WHERE client_id = $1 AND loan_id = $2 ORDER BY uploaded_at DESC', [
          req.user.id,
          loan_id,
        ])
      : await pool.query('SELECT * FROM documents WHERE client_id = $1 ORDER BY uploaded_at DESC', [req.user.id]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not fetch documents' });
  }
});

// DELETE /api/documents/:id - client removes a document they own
router.delete('/:id', authorize('client'), async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM documents WHERE id = $1 AND client_id = $2 RETURNING id', [
      req.params.id,
      req.user.id,
    ]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Document not found' });
    res.json({ message: 'Document removed' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Could not delete document' });
  }
});

module.exports = router;
