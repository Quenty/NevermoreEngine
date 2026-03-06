import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

vi.mock('@quenty/cli-output-helpers', () => ({
  OutputHelper: {
    error: vi.fn(),
    warn: vi.fn(),
    info: vi.fn(),
    verbose: vi.fn(),
  },
}));

import { validateCookieAsync } from './index.js';
import { OutputHelper } from '@quenty/cli-output-helpers';

const mockedOutputHelper = vi.mocked(OutputHelper);

describe('validateCookieAsync', () => {
  const originalFetch = globalThis.fetch;

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it('continues without error when cookie is valid (HTTP 200)', async () => {
    const exitSpy = vi.spyOn(process, 'exit').mockImplementation(() => undefined as never);
    globalThis.fetch = vi.fn().mockResolvedValue({ status: 200 });

    await validateCookieAsync('valid-cookie');

    expect(exitSpy).not.toHaveBeenCalled();
    expect(mockedOutputHelper.error).not.toHaveBeenCalled();
    expect(mockedOutputHelper.warn).not.toHaveBeenCalled();
  });

  it('exits with error when cookie is invalid (HTTP 401)', async () => {
    const exitSpy = vi.spyOn(process, 'exit').mockImplementation(() => undefined as never);
    globalThis.fetch = vi.fn().mockResolvedValue({ status: 401 });

    await validateCookieAsync('expired-cookie');

    expect(mockedOutputHelper.error).toHaveBeenCalledWith(
      'ROBLOSECURITY cookie is invalid or expired (HTTP 401). Update the cookie and try again.',
    );
    expect(exitSpy).toHaveBeenCalledWith(1);
  });

  it('continues with warning when fetch throws (network error)', async () => {
    const exitSpy = vi.spyOn(process, 'exit').mockImplementation(() => undefined as never);
    globalThis.fetch = vi.fn().mockRejectedValue(new Error('network error'));

    await validateCookieAsync('some-cookie');

    expect(mockedOutputHelper.warn).toHaveBeenCalledWith(
      'Could not validate ROBLOSECURITY cookie (network error). Continuing anyway.',
    );
    expect(exitSpy).not.toHaveBeenCalled();
    expect(mockedOutputHelper.error).not.toHaveBeenCalled();
  });
});
