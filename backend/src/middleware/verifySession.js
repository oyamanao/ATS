const { supabase } = require('../config/supabase');
const logger = require('../utils/logger');

const ALLOWED_EMAIL_DOMAIN = process.env.ALLOWED_EMAIL_DOMAIN || '@iiitdwd.ac.in';

if (!supabase) {
  logger.warn('Supabase is not configured; authentication endpoints are unavailable');
}

/**
 * Express middleware: validates a Supabase JWT Bearer token and enforces
 * university email domain restriction (case-insensitive).
 *
 * On success, attaches `req.user` (the Supabase user object).
 */
async function verifySession(req, res, next) {
  if (!supabase) {
    return res.status(503).json({ error: 'Authentication service unavailable: Supabase is not configured.' });
  }

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: Bearer token missing' });
  }

  const token = authHeader.slice(7);

  try {
    const {
      data: { user },
      error,
    } = await supabase.auth.getUser(token);

    if (error || !user) {
      logger.warn('Invalid session token presented', { error: error?.message });
      return res.status(401).json({ error: 'Invalid or expired session' });
    }

    if (!user.email || !user.email.toLowerCase().endsWith(ALLOWED_EMAIL_DOMAIN.toLowerCase())) {
      logger.warn('Non-university email rejected', { email: user.email });
      return res.status(403).json({ error: 'Access restricted to university accounts' });
    }

    req.user = user;
    next();
  } catch (err) {
    logger.error('Authentication subsystem error', { err });
    return res.status(500).json({ error: 'Authentication service unavailable' });
  }
}

module.exports = { verifySession };
