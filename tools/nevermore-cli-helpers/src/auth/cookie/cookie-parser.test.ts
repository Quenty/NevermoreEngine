import { describe, it, expect } from 'vitest';
import { COOKIE_NAME, parseStudioCookieValue } from './cookie-parser.js';

describe('COOKIE_NAME', () => {
  it('equals .ROBLOSECURITY', () => {
    expect(COOKIE_NAME).toBe('.ROBLOSECURITY');
  });
});

describe('parseStudioCookieValue', () => {
  it('parses COOK::<value> format with angle brackets', () => {
    const result = parseStudioCookieValue('COOK::<abc123>');
    expect(result).toBe('abc123');
  });

  it('parses value from comma-separated list', () => {
    const result = parseStudioCookieValue('OTHER::stuff,COOK::<secret>');
    expect(result).toBe('secret');
  });

  it('returns undefined for plain text', () => {
    expect(parseStudioCookieValue('just a string')).toBeUndefined();
  });

  it('returns undefined for COOK:: without angle brackets', () => {
    expect(parseStudioCookieValue('COOK::noBrackets')).toBeUndefined();
  });

  it('returns undefined for empty string', () => {
    expect(parseStudioCookieValue('')).toBeUndefined();
  });

  it('handles a realistic cookie value', () => {
    const cookie = '_|WARNING:-DO-NOT-SHARE|_abc123def456';
    const result = parseStudioCookieValue(`COOK::<${cookie}>`);
    expect(result).toBe(cookie);
  });
});
