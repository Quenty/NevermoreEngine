import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

import { validateCookieAsync } from './index.js';

describe('validateCookieAsync', () => {
  const originalFetch = globalThis.fetch;

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('returns valid when cookie is accepted (HTTP 200)', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({ status: 200 });

    const result = await validateCookieAsync('valid-cookie');

    expect(result).toEqual({ valid: true });
  });

  it('returns invalid with status when cookie is rejected (HTTP 401)', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({ status: 401 });

    const result = await validateCookieAsync('expired-cookie');

    expect(result).toEqual({ valid: false, reason: 'invalid', status: 401 });
  });

  it('returns network_error when fetch throws', async () => {
    globalThis.fetch = vi.fn().mockRejectedValue(new Error('network error'));

    const result = await validateCookieAsync('some-cookie');

    expect(result).toEqual({ valid: false, reason: 'network_error' });
  });
});
