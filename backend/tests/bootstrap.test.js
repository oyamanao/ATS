describe('Backend startup config', () => {
  const originalEnv = { ...process.env };

  beforeEach(() => {
    jest.resetModules();
    delete process.env.SUPABASE_URL;
    delete process.env.SUPABASE_SERVICE_ROLE_KEY;
    delete process.env.ALLOWED_EMAIL_DOMAIN;
    delete process.env.SHARED_CLASS_SECRET;
    delete process.env.TOTP_INTERVAL;
    delete process.env.PORT;
    delete process.env.HOST;
  });

  afterEach(() => {
    process.env = { ...originalEnv };
  });

  test('server can be imported without a configured Supabase environment', () => {
    expect(() => require('../server')).not.toThrow();
  });
});
