require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');

const fs = require('fs');

const authRoutes = require('./routes/auth');
const branchRoutes = require('./routes/branches');
const profileRoutes = require('./routes/profile');
const loanRoutes = require('./routes/loans');
const documentRoutes = require('./routes/documents');
const notificationRoutes = require('./routes/notifications');
const adminRoutes = require('./routes/admin');
const reportRoutes = require('./routes/reports');
const simulatedRoutes = require('./routes/simulated');

const app = express();

app.use(cors({
  origin: '*',
  methods: ['GET','POST','PUT','PATCH','DELETE','OPTIONS'],
  allowedHeaders: ['Content-Type','Authorization'],
  credentials: true,
}));
app.options('*', cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve uploaded documents (ID scans, title deeds, etc.)
app.use('/uploads', express.static(path.join(__dirname, process.env.UPLOAD_DIR || 'uploads')));

app.get('/health', (req, res) => res.json({ status: 'ok', time: new Date().toISOString() }));

app.use('/api/auth', authRoutes);
app.use('/api/branches', branchRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/loans', loanRoutes);
app.use('/api/documents', documentRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api', simulatedRoutes); // /api/assistant/*, /api/farming-advice

// Serve Flutter web app build if available
const webBuildPath = path.join(__dirname, '../frontend/vunaflow_app/build/web');
if (fs.existsSync(webBuildPath)) {
  app.use(express.static(webBuildPath));
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api') || req.path.startsWith('/uploads')) {
      return next();
    }
    res.sendFile(path.join(webBuildPath, 'index.html'));
  });
} else {
  app.get('/', (req, res) => res.json({ status: 'VunaFlow API is running' }));
}

// 404 handler
app.use((req, res) => res.status(404).json({ error: 'Route not found' }));

// Global error handler
app.use((err, req, res, next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error' });
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`🌱 VunaFlow API & Web App listening on port ${PORT}`);
});
