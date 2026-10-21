const { validateTotp, generateCurrentTotp } = require('../src/services/totpService');

describe('TOTP Service', () => {
  it('should accept the current TOTP code', () => {
    const currentCode = generateCurrentTotp();
    expect(currentCode).toHaveLength(6);
    expect(validateTotp(currentCode)).toBe(true);
  });

  it('should reject a bogus code', () => {
    expect(validateTotp('000000')).toBe(false);
  });

  it('should reject an empty string or malformed code', () => {
    expect(validateTotp('')).toBe(false);
    expect(validateTotp('abc')).toBe(false);
    expect(validateTotp(null)).toBe(false);
  });
});
