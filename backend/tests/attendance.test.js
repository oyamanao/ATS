const request = require('supertest');
const app = require('../server');
const { supabase } = require('../src/config/supabase');
const { generateCurrentTotp } = require('../src/services/totpService');
const crypto = require('crypto');

describe('POST /api/attendance/mark Comprehensive Tests', () => {
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

  beforeEach(() => {
    jest.clearAllMocks();
    // Default valid user auth
    jest.spyOn(supabase.auth, 'getUser').mockResolvedValue({
      data: {
        user: {
          id: 'user-uuid-1234',
          email: '21bcs001@iiitdwd.ac.in',
        },
      },
      error: null,
    });
  });

  it('should return 400 if qrPayload or signature is missing', async () => {
    const res = await request(app)
      .post('/api/attendance/mark')
      .set('Authorization', 'Bearer valid_token')
      .send({ qrPayload: 'attendance://CS101/123456' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('Missing qrPayload or signature');
  });

  it('should return 400 if qrPayload or signature is not a string', async () => {
    const res = await request(app)
      .post('/api/attendance/mark')
      .set('Authorization', 'Bearer valid_token')
      .send({ qrPayload: 123456, signature: true });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('Missing qrPayload or signature');
  });

  it('should return 400 if qrPayload is malformed', async () => {
    const res = await request(app)
      .post('/api/attendance/mark')
      .set('Authorization', 'Bearer valid_token')
      .send({ qrPayload: 'not-a-valid-url', signature: 'dummy-sig' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('Malformed QR payload');
  });

  it('should return 400 if TOTP code is expired or invalid', async () => {
    const res = await request(app)
      .post('/api/attendance/mark')
      .set('Authorization', 'Bearer valid_token')
      .send({
        qrPayload: 'attendance://CS101/000000',
        signature: 'dummy-sig',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('QR Code expired');
  });

  it('should return 403 if device public key is not registered', async () => {
    const currentTotp = generateCurrentTotp();
    const qrPayload = `attendance://CS101/${currentTotp}`;
    const sig = signPayload(qrPayload);

    // Mock student_devices query to return null
    jest.spyOn(supabase, 'from').mockImplementationOnce(() => ({
      select: () => ({
        eq: () => ({
          single: async () => ({ data: null, error: new Error('Device not found') }),
          maybeSingle: async () => ({ data: null, error: new Error('Device not found') }),
        }),
      }),
    }));

    const res = await request(app)
      .post('/api/attendance/mark')
      .set('Authorization', 'Bearer valid_token')
      .send({ qrPayload, signature: sig });

    expect(res.status).toBe(403);
    expect(res.body.error).toContain('Device not registered');
  });

  it('should return 400 if cryptographic signature verification fails', async () => {
    const currentTotp = generateCurrentTotp();
    const qrPayload = `attendance://CS101/${currentTotp}`;

    // Mock student_devices query to return valid registered public key
    jest.spyOn(supabase, 'from').mockImplementationOnce(() => ({
      select: () => ({
        eq: () => ({
          single: async () => ({ data: { public_key: publicKeyPem }, error: null }),
          maybeSingle: async () => ({ data: { public_key: publicKeyPem }, error: null }),
        }),
      }),
    }));

    const res = await request(app)
      .post('/api/attendance/mark')
      .set('Authorization', 'Bearer valid_token')
      .send({ qrPayload, signature: 'invalid_forged_signature_base64' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('Cryptographic verification failed');
  });

  it('should return 400 if token was already processed (replay attack)', async () => {
    const currentTotp = generateCurrentTotp();
    const qrPayload = `attendance://CS101/${currentTotp}`;
    const sig = signPayload(qrPayload);

    // Mock student_devices and processed_tokens
    const fromMock = jest.spyOn(supabase, 'from');
    fromMock.mockImplementation((table) => {
      if (table === 'student_devices') {
        const queryBuilder = {
          eq: () => queryBuilder,
          single: async () => ({ data: { public_key: publicKeyPem }, error: null }),
          maybeSingle: async () => ({ data: { public_key: publicKeyPem }, error: null }),
        };
        return {
          select: () => queryBuilder,
        };
      }
      if (table === 'processed_tokens') {
        const queryBuilder = {
          eq: () => queryBuilder,
          single: async () => ({ data: { id: 'token-uuid-exists' }, error: null }),
          maybeSingle: async () => ({ data: { id: 'token-uuid-exists' }, error: null }),
        };
        return {
          select: () => queryBuilder,
        };
      }
      return {};
    });

    const res = await request(app)
      .post('/api/attendance/mark')
      .set('Authorization', 'Bearer valid_token')
      .send({ qrPayload, signature: sig });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('QR token already used');
  });

  it('should successfully record attendance for valid request', async () => {
    const currentTotp = generateCurrentTotp();
    const qrPayload = `attendance://CS101/${currentTotp}`;
    const sig = signPayload(qrPayload);

    const fromMock = jest.spyOn(supabase, 'from');
    fromMock.mockImplementation((table) => {
      if (table === 'student_devices') {
        const queryBuilder = {
          eq: () => queryBuilder,
          single: async () => ({ data: { public_key: publicKeyPem }, error: null }),
          maybeSingle: async () => ({ data: { public_key: publicKeyPem }, error: null }),
        };
        return {
          select: () => queryBuilder,
        };
      }
      if (table === 'processed_tokens') {
        const queryBuilder = {
          eq: () => queryBuilder,
          single: async () => ({ data: null, error: null }),
          maybeSingle: async () => ({ data: null, error: null }),
        };
        return {
          select: () => queryBuilder,
          insert: async () => ({ error: null }),
        };
      }
      if (table === 'attendance_logs') {
        return {
          insert: async () => ({ error: null }),
        };
      }
      return {};
    });

    const res = await request(app)
      .post('/api/attendance/mark')
      .set('Authorization', 'Bearer valid_token')
      .send({ qrPayload, signature: sig });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('SUCCESS');
    expect(res.body.message).toContain('Attendance verified');
  });
});
