require('dotenv').config();
const express = require('express');
const cors = require('cors');
const logger = require('./src/utils/logger');
const attendanceRoutes = require('./src/routes/attendance');
const teacherRoutes = require('./src/routes/teacher');

const app = express();

// Disable x-powered-by header for security
app.disable('x-powered-by');

// ── Security Headers ──────────────────────────────────────────────────────────
app.use((_req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'SAMEORIGIN');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  next();
});

// ── Middleware ───────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10kb' })); // Prevent oversized payloads

const corsOrigin = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(',').map((o) => o.trim())
  : true;

app.use(cors({
  origin: corsOrigin,
}));

// ── Routes ───────────────────────────────────────────────────────────────────
app.use('/api/attendance', attendanceRoutes);
app.use('/api/teacher', teacherRoutes);
app.use('/teacher', teacherRoutes);

// ── Health Check ─────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// ── 404 Handler ──────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// ── Error Handler ────────────────────────────────────────────────────────────
app.use((err, _req, res, _next) => {
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    logger.warn('Malformed JSON payload received', { err: err.message });
    return res.status(400).json({ error: 'Invalid JSON payload' });
  }

  logger.error('Unhandled exception', { err });
  return res.status(500).json({ error: 'Internal server error' });
});

// ── Server Binding ───────────────────────────────────────────────────────────
const PORT = parseInt(process.env.PORT || '3000', 10);
const HOST = process.env.HOST || '0.0.0.0';

if (require.main === module) {
  app.listen(PORT, HOST, () => {
    logger.info(`Attendance Server running on ${HOST}:${PORT} (local intranet only)`);
  });
}

module.exports = app; // Export for tests
