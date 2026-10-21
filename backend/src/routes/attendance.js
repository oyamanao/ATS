const express = require('express');
const { supabase } = require('../config/supabase');
const { validateTotp } = require('../services/totpService');
const { verifySignature } = require('../services/signatureService');
const { verifySession } = require('../middleware/verifySession');
const { attendanceLimiter } = require('../middleware/rateLimiter');
const logger = require('../utils/logger');

const router = express.Router();

/**
 * POST /api/attendance/mark
 *
 * Body: { qrPayload: string, signature: string }
 *
 * QR Payload format: attendance://<classId>/<6-digit-TOTP>
 *
 * Security pipeline:
 *   1. JWT auth + domain check (middleware)
 *   2. Rate limit (middleware)
 *   3. Parse QR payload
 *   4. Validate TOTP code (time window)
 *   5. Fetch hardware public key from DB
 *   6. Verify RSA-SHA256 signature
 *   7. Check token idempotency (prevent replay)
 *   8. Record token + log attendance
 */
router.post('/mark', verifySession, attendanceLimiter, async (req, res) => {
  const { qrPayload, signature } = req.body;
  const userId = req.user.id;
  const userEmail = req.user.email;

  if (!qrPayload || !signature) {
    return res.status(400).json({ error: 'Missing qrPayload or signature in request body' });
  }

  try {
    // ── Step 3: Parse QR payload ────────────────────────────────────────────
    let classId, clientTotp;
    try {
      const url = new URL(qrPayload);
      classId = url.host;
      clientTotp = url.pathname.replace(/^\//, '');
    } catch {
      return res.status(400).json({ error: 'Malformed QR payload' });
    }

    if (!classId || !clientTotp) {
      return res.status(400).json({ error: 'Invalid QR payload structure' });
    }

    // ── Step 4: TOTP Validation ─────────────────────────────────────────────
    const isTotpValid = validateTotp(clientTotp);
    if (!isTotpValid) {
      logger.warn('Expired/invalid TOTP presented', { userId, classId });
      return res.status(400).json({ error: 'QR Code expired. Please scan the live screen again.' });
    }

    // ── Step 5: Fetch public key ────────────────────────────────────────────
    const { data: device, error: dbErr } = await supabase
      .from('student_devices')
      .select('public_key')
      .eq('user_id', userId)
      .single();

    if (dbErr || !device) {
      logger.warn('Unregistered device attempted attendance', { userId });
      return res.status(403).json({ error: 'Device not registered. Contact your Faculty Advisor.' });
    }

    // ── Step 6: Signature Verification ─────────────────────────────────────
    const isValidSig = verifySignature(qrPayload, signature, device.public_key);
    if (!isValidSig) {
      logger.warn('Signature verification failed', { userId });
      return res.status(400).json({ error: 'Cryptographic verification failed.' });
    }

    // ── Step 7: Idempotency — prevent token replay ──────────────────────────
    const { data: existingToken } = await supabase
      .from('processed_tokens')
      .select('id')
      .eq('token', clientTotp)
      .single();

    if (existingToken) {
      logger.warn('Duplicate token replay attempt detected', { userId, token: clientTotp });
      return res.status(400).json({ error: 'QR token already used. Attendance already recorded or token replayed.' });
    }

    // ── Step 8: Record processed token + log attendance ─────────────────────
    const [tokenInsert, attendanceInsert] = await Promise.all([
      supabase.from('processed_tokens').insert({ token: clientTotp, user_id: userId }),
      supabase.from('attendance_logs').insert({
        user_id: userId,
        class_id: classId,
        email: userEmail,
        timestamp: new Date().toISOString(),
      }),
    ]);

    if (tokenInsert.error || attendanceInsert.error) {
      logger.error('Database write failed', {
        tokenErr: tokenInsert.error,
        attendErr: attendanceInsert.error,
      });
      return res.status(500).json({ error: 'Attendance could not be recorded. Try again.' });
    }

    logger.info('Attendance recorded successfully', { userId, classId, email: userEmail });
    return res.status(200).json({ status: 'SUCCESS', message: 'Attendance verified and recorded.' });

  } catch (err) {
    logger.error('Unhandled error in /api/attendance/mark', { err });
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
