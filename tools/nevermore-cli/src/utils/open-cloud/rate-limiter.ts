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

const DEFAULT_MAX_CONCURRENCY = 4;
const RETRY_JITTER_FRACTION = 0.3;

export interface RateLimiterOptions {
  /**
   * Maximum number of concurrent in-flight requests. Defaults to 4.
   * Pick higher only after measuring — the default balances wallclock against
   * keeping a tight feedback loop on `x-ratelimit-remaining`.
   */
  maxConcurrency?: number;
}

/**
 * Shared rate limiter for Roblox Open Cloud API requests.
 *
 * - Tracks `x-ratelimit-remaining` and `x-ratelimit-reset` (seconds until reset)
 * - Caps concurrent in-flight requests (default 4) via a semaphore so callers
 *   benefit from parallelism (e.g. multi-place deploys) while still getting
 *   header feedback before each wave widens past the quota
 * - Retries on 429 with exponential back-off plus 0-30% additive jitter so
 *   concurrent callers don't all wake up on the same millisecond and re-collide
 */
export class RateLimiter {
  private _remaining: number | null = null;
  private _resetAtMs: number | null = null;

  /** Queue of callers waiting to send a request. */
  private _queue: Array<() => void> = [];
  private _inflight = 0;
  private _maxConcurrency: number;

  constructor(options: RateLimiterOptions = {}) {
    this._maxConcurrency = Math.max(
      1,
      options.maxConcurrency ?? DEFAULT_MAX_CONCURRENCY
    );
  }

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
   * Acquire a send slot. Up to `_maxConcurrency` callers can hold a slot at
   * once — beyond that they queue. The cap keeps the header-feedback loop
   * tight without artificially serializing unrelated work.
   */
  private _acquireAsync(): Promise<void> {
    if (this._inflight < this._maxConcurrency) {
      this._inflight++;
      return Promise.resolve();
    }

    return new Promise<void>((resolve) => {
      this._queue.push(resolve);
    });
  }

  private _release(): void {
    const next = this._queue.shift();
    if (next) {
      // Slot is handed off — _inflight stays the same.
      next();
    } else {
      this._inflight--;
    }
  }

  /**
   * Wraps a fetch call with rate-limit awareness:
   * - Caps concurrency at `_maxConcurrency` (default 4) so we keep getting
   *   header feedback before each new wave fans out
   * - Delays if we know we're out of quota
   * - Retries on 429 with jittered back-off (up to 3 attempts)
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
        const baseSec = retryAfter
          ? parseFloat(retryAfter)
          : 10 * (attempt + 1);
        // Additive jitter only — never wait less than retry-after asked for,
        // but desynchronize concurrent callers so they don't all retry on the
        // exact same millisecond and re-collide on the next attempt.
        const waitSec = baseSec * (1 + Math.random() * RETRY_JITTER_FRACTION);

        OutputHelper.warn(
          `429 on ${route} (attempt ${
            attempt + 1
          }/${maxRetries}). Retrying in ${waitSec.toFixed(
            1
          )}s (Roblox requested)...`
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
