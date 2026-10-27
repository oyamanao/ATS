const { TOTP } = require('otpauth');

function getSecret() {
  return (process.env.SHARED_CLASS_SECRET || 'KVKXG2LEMYFA====').trim();
}

function getInterval() {
  return parseInt(process.env.TOTP_INTERVAL || '10', 10);
}

/**
 * Validates a client-supplied TOTP code.
 * Accepts the current window and one previous window to account for clock drift.
 *
 * @param {string} clientCode - 6-digit TOTP code from the scanned QR.
 * @returns {boolean} true if valid, false if expired or forged.
 */
function validateTotp(clientCode) {
  if (!clientCode || typeof clientCode !== 'string' || clientCode.trim().length !== 6) {
    return false;
  }

  try {
    const totp = new TOTP({
      secret: getSecret(),
      algorithm: 'SHA256',
      digits: 6,
      period: getInterval(),
    });

    // delta: number of periods the code may be off. 1 = accept current + 1 previous period.
    const delta = totp.validate({ token: clientCode.trim(), window: 1 });
    return delta !== null;
  } catch (_err) {
    return false;
  }
}

/**
 * Generates the current TOTP code (for teacher screen / testing purposes).
 * @returns {string} Current 6-digit TOTP code.
 */
function generateCurrentTotp() {
  const totp = new TOTP({
    secret: getSecret(),
    algorithm: 'SHA256',
    digits: 6,
    period: getInterval(),
  });
  return totp.generate();
}

module.exports = { validateTotp, generateCurrentTotp };
