import { OutputHelper } from '@quenty/cli-output-helpers';

/**
 * Extracts a short route label from a URL for logging.
 * e.g. "https://apis.roblox.com/cloud/v2/universes/123/places/456/..." → "places/456/..."
 */
function _extractRoute(url: string | URL | Request): string {
  try {
    const urlStr =
      typeof url === 'string' ? url : url instanceof URL ? url.href : url.url;
    const parsed = new URL(urlStr);
    // Drop the host, keep the last meaningful path segments
    const segments = parsed.pathname.split('/').filter(Boolean);
    // Take last 3 segments for a readable label
    return segments.slice(-3).join('/');
  } catch {
    return 'unknown';
  }
}

/**
 * Shared rate limiter for Roblox Open Cloud API requests.
 *
 * - Tracks `x-ratelimit-remaining` and `x-ratelimit-reset` (seconds until reset)
 * - Serializes concurrent callers through a queue so only one request is in-flight
 *   at a time, preventing bursts that blow past the limit before headers arrive
 * - Retries on 429 with exponential back-off (up to 3 attempts)
 */
export class RateLimiter {
  private _remaining: number | null = null;
  private _resetAtMs: number | null = null;

  /** Queue of callers waiting to send a request. */
  private _queue: Array<() => void> = [];
  private _inflight = false;

  private _updateFromHeaders(headers: Headers): void {
    const remaining = headers.get('x-ratelimit-remaining');
    const reset = headers.get('x-ratelimit-reset');

    if (remaining !== null) {
      this._remaining = parseInt(remaining, 10);
    }

    // x-ratelimit-reset is seconds until reset, not an epoch timestamp
    if (reset !== null) {
      const resetSec = parseFloat(reset);
      this._resetAtMs = Date.now() + resetSec * 1000;
    }
  }

  private async _waitIfNeededAsync(route: string): Promise<void> {
    if (
      this._remaining !== null &&
      this._remaining <= 0 &&
      this._resetAtMs !== null
    ) {
      const waitMs = this._resetAtMs - Date.now();
      if (waitMs > 0) {
        const waitSec = Math.ceil(waitMs / 1000);
        OutputHelper.warn(
          `Rate limit reached on ${route}. Waiting ${waitSec}s (Roblox requested)...`
        );
        await new Promise((resolve) => setTimeout(resolve, waitMs));
      }
      // Reset after waiting so the next request can proceed
      this._remaining = null;
      this._resetAtMs = null;
    }
  }

  /**
   * Acquire the send slot. Only one request at a time goes through
   * so we always have fresh header data before deciding to send.
   */
  private _acquireAsync(): Promise<void> {
    if (!this._inflight) {
      this._inflight = true;
      return Promise.resolve();
    }

    return new Promise<void>((resolve) => {
      this._queue.push(resolve);
    });
  }

  private _release(): void {
    const next = this._queue.shift();
    if (next) {
      next();
    } else {
      this._inflight = false;
    }
  }

  /**
   * Wraps a fetch call with rate-limit awareness:
   * - Serializes callers so we always have current header state
   * - Delays if we know we're out of quota
   * - Retries on 429 with back-off (up to 3 attempts)
   * - Tracks rate-limit headers from every response
   */
  async fetchAsync(
    url: string | URL | Request,
    init?: RequestInit
  ): Promise<Response> {
    await this._acquireAsync();

    const route = _extractRoute(url);

    try {
      await this._waitIfNeededAsync(route);

      let lastResponse: Response | null = null;
      const maxRetries = 3;

      for (let attempt = 0; attempt < maxRetries; attempt++) {
        const response = await fetch(url, init);
        this._updateFromHeaders(response.headers);

        if (response.status !== 429) {
          return response;
        }

        lastResponse = response;

        const retryAfter = response.headers.get('retry-after');
        const waitSec = retryAfter
          ? parseFloat(retryAfter)
          : 10 * (attempt + 1);

        OutputHelper.warn(
          `429 on ${route} (attempt ${
            attempt + 1
          }/${maxRetries}). Retrying in ${waitSec}s (Roblox requested)...`
        );
        await new Promise((resolve) => setTimeout(resolve, waitSec * 1000));
      }

      // All retries exhausted — return the last 429 response
      return lastResponse!;
    } finally {
      this._release();
    }
  }
}
