// Polyfill WebSocket for Node.js < 22.
// @supabase/realtime-js v2.x requires a global WebSocket constructor.
// Node.js 22+ ships one natively; older versions do not, causing the
// supabase createClient() call to throw at module load time during tests.
if (typeof globalThis.WebSocket === 'undefined') {
  // eslint-disable-next-line no-undef
  const { WebSocket } = require('ws');
  globalThis.WebSocket = WebSocket;
}

process.env.SUPABASE_URL = process.env.SUPABASE_URL || 'http://127.0.0.1:8000';
process.env.SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'dummy_test_service_key_for_testing';
process.env.ALLOWED_EMAIL_DOMAIN = '@iiitdwd.ac.in';
process.env.SHARED_CLASS_SECRET = 'KVKXG2LEMYFA====';
process.env.TOTP_INTERVAL = '10';
process.env.PORT = '3000';
