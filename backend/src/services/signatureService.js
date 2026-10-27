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
  if (
    !payload ||
    !signatureBase64 ||
    !rawPublicKey ||
    typeof payload !== 'string' ||
    typeof signatureBase64 !== 'string' ||
    typeof rawPublicKey !== 'string'
  ) {
    return false;
  }

  try {
    let publicKeyPem = rawPublicKey.trim();

    // Normalize: wrap in PEM headers and split into standard 64-char lines if not already PEM
    if (!publicKeyPem.includes('-----BEGIN PUBLIC KEY-----')) {
      const cleanBase64 = publicKeyPem.replace(/\s+/g, '');
      const chunks = cleanBase64.match(/.{1,64}/g) || [cleanBase64];
      publicKeyPem = `-----BEGIN PUBLIC KEY-----\n${chunks.join('\n')}\n-----END PUBLIC KEY-----`;
    }

    const verifier = crypto.createVerify('SHA256');
    verifier.update(payload, 'utf8');
    verifier.end();

    return verifier.verify(publicKeyPem, signatureBase64, 'base64');
  } catch (_err) {
    return false;
  }
}

module.exports = { verifySignature };
