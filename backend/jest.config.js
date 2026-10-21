/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.js'],
  setupFiles: ['<rootDir>/tests/setup.js'],
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/config/supabase.js',
    '!src/utils/logger.js',
  ],
  coverageThreshold: {
    global: {
      lines: 70,
    },
  },
};
