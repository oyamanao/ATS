const request = require('supertest');
const app = require('../server');

describe('API Route Tests', () => {
  describe('Security Headers', () => {
    it('should include nosniff and frame options and omit x-powered-by', async () => {
      const res = await request(app).get('/health');
      expect(res.headers['x-content-type-options']).toBe('nosniff');
      expect(res.headers['x-frame-options']).toBe('SAMEORIGIN');
      expect(res.headers['x-powered-by']).toBeUndefined();
    });
  });

  describe('GET /health', () => {
    it('should return 200 with status ok', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
      expect(res.body.time).toBeDefined();
    });
  });

  describe('GET /api/teacher/token', () => {
    it('should return valid rolling TOTP token and classroom URI', async () => {
      const res = await request(app).get('/api/teacher/token?classId=CS101');
      expect(res.status).toBe(200);
      expect(res.body.classId).toBe('CS101');
      expect(res.body.totpCode).toHaveLength(6);
      expect(res.body.uri).toBe(`attendance://CS101/${res.body.totpCode}`);
      expect(res.body.interval).toBe(10);
    });
  });

  describe('GET /teacher/display', () => {
    it('should return HTML classroom display page', async () => {
      const res = await request(app).get('/teacher/display?classId=A101');
      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toContain('text/html');
      expect(res.text).toContain('Classroom A101');
    });
  });

  describe('POST /api/attendance/mark - auth and payload validation', () => {
    it('should reject request when Authorization header is missing', async () => {
      const res = await request(app)
        .post('/api/attendance/mark')
        .send({ qrPayload: 'attendance://CS101/123456', signature: 'sig' });
      expect(res.status).toBe(401);
      expect(res.body.error).toContain('token missing');
    });

    it('should reject request when body is missing required fields', async () => {
      const res = await request(app)
        .post('/api/attendance/mark')
        .set('Authorization', 'Bearer invalid_token')
        .send({});
      expect([400, 401]).toContain(res.status);
    });
  });

  describe('Error Handling Middleware', () => {
    it('should return 400 when body parser encounters malformed JSON', async () => {
      const res = await request(app)
        .post('/api/attendance/mark')
        .set('Content-Type', 'application/json')
        .send('{"brokenJson: 123');

      expect(res.status).toBe(400);
      expect(res.body.error).toBe('Invalid JSON payload');
    });
  });

  describe('404 Handler', () => {
    it('should return 404 for non-existent endpoint', async () => {
      const res = await request(app).get('/api/non-existent-endpoint');
      expect(res.status).toBe(404);
      expect(res.body.error).toBe('Endpoint not found');
    });
  });
});
