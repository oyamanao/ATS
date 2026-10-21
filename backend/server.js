require('dotenv').config();
const express = require('express');
const cors = require('cors');
const logger = require('./src/utils/logger');
const attendanceRoutes = require('./src/routes/attendance');
const teacherRoutes = require('./src/routes/teacher');

const app = express();

// ── Middleware ───────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10kb' })); // Prevent oversized payloads
app.use(cors({
  origin: true, // Allow teacher projector web dashboard
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
  logger.error('Unhandled exception', { err });
  res.status(500).json({ error: 'Internal server error' });
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
