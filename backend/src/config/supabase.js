const { createClient } = require('@supabase/supabase-js');

const DEFAULT_SERVICE_ROLE_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3MDAwMDAwMDAsImV4cCI6MjA1MDAwMDAwMH0.qo7BEOW9yB2xFpo8S-OzzMEqY3qHvGFakU2yRG-5Rtc';

const SUPABASE_URL = process.env.SUPABASE_URL || 'http://127.0.0.1:8000';
let rawKey = process.env.SUPABASE_SERVICE_ROLE_KEY || DEFAULT_SERVICE_ROLE_KEY;
if (
  rawKey === 'local-dev-service-role-key' ||
  rawKey === 'super-secret-jwt-token-with-at-least-32-chars-long'
) {
  rawKey = DEFAULT_SERVICE_ROLE_KEY;
}

const SUPABASE_SERVICE_ROLE_KEY = rawKey;
const supabaseConfigured = Boolean(SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY);

const supabase = supabaseConfigured
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })
  : null;

module.exports = { supabase, supabaseConfigured };
