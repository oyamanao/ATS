const crypto = require('crypto');
const { verifySignature } = require('../src/services/signatureService');

describe('Signature Service', () => {
  let privateKey, publicKeyPem;

  beforeAll(() => {
    const { privateKey: priv, publicKey: pub } = crypto.generateKeyPairSync('rsa', {
      modulusLength: 2048,
    });
    privateKey = priv;
    publicKeyPem = pub.export({ type: 'spki', format: 'pem' });
  });

  function signPayload(payload) {
    const signer = crypto.createSign('SHA256');
    signer.update(payload, 'utf8');
    signer.end();
    return signer.sign(privateKey, 'base64');
  }

  it('should accept a valid RSA-SHA256 signature', () => {
    const payload = 'attendance://CS101/123456';
    const sig = signPayload(payload);
    expect(verifySignature(payload, sig, publicKeyPem)).toBe(true);
  });

  it('should reject a tampered payload', () => {
    const payload = 'attendance://CS101/123456';
    const sig = signPayload(payload);
    expect(verifySignature('attendance://CS101/999999', sig, publicKeyPem)).toBe(false);
  });

  it('should reject an invalid signature format', () => {
    expect(verifySignature('attendance://CS101/123456', 'invalid_signature_base64==', publicKeyPem)).toBe(false);
  });

  it('should correctly handle raw base64 public key without PEM headers', () => {
    const payload = 'attendance://CS101/123456';
    const sig = signPayload(payload);
    const rawBase64 = publicKeyPem
      .replace('-----BEGIN PUBLIC KEY-----', '')
      .replace('-----END PUBLIC KEY-----', '')
      .replace(/\r?\n|\r/g, '');
    expect(verifySignature(payload, sig, rawBase64)).toBe(true);
  });
});
