const rateLimit = require('express-rate-limit');

/**
 * Limits each IP to 5 attendance mark attempts per 30 seconds.
 * Prevents brute-force token replay attempts.
 */
const attendanceLimiter = rateLimit({
  windowMs: 30 * 1000, // 30 seconds
  max: process.env.NODE_ENV === 'test' ? 1000 : 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests. Please wait before retrying.' },
});

module.exports = { attendanceLimiter };
