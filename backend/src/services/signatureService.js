const crypto = require('crypto');

/**
 * Verifies a base64-encoded RSA-SHA256 signature against a payload
 * using the student's hardware-bound public key stored in the database.
 *
 * @param {string} payload - The original signed data (QR payload string).
 * @param {string} signatureBase64 - Base64-encoded signature from the mobile client.
 * @param {string} rawPublicKey - PEM or raw base64 public key from database.
 * @returns {boolean} true if the signature is valid.
 */
function verifySignature(payload, signatureBase64, rawPublicKey) {
  // Normalize: wrap in PEM headers if not already present
  const publicKeyPem = rawPublicKey.includes('-----BEGIN PUBLIC KEY-----')
    ? rawPublicKey
    : `-----BEGIN PUBLIC KEY-----\n${rawPublicKey}\n-----END PUBLIC KEY-----`;

  const verifier = crypto.createVerify('SHA256');
  verifier.update(payload, 'utf8');
  verifier.end();

  try {
    return verifier.verify(publicKeyPem, signatureBase64, 'base64');
  } catch (_err) {
    return false;
  }
}

module.exports = { verifySignature };
