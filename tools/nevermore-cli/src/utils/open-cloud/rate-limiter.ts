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
const DEFAULT_MAX_RETRIES = 6;
const RETRY_JITTER_FRACTION = 0.3;
const RETRYABLE_SERVER_ERROR_STATUSES = new Set([502, 503, 504]);

export interface RateLimiterOptions {
  /**
   * Maximum number of concurrent in-flight requests. Defaults to 4.
   * Pick higher only after measuring — the default balances wallclock against
   * keeping a tight feedback loop on `x-ratelimit-remaining`.
   */
  maxConcurrency?: number;
  /**
   * Total attempts per request before giving up (including the initial try).
   * Defaults to 6, sized to ride out the Luau-execution endpoint's burst
   * windows during a multi-place deploy.
   */
  maxRetries?: number;
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
  private _maxRetries: number;

  constructor(options: RateLimiterOptions = {}) {
    this._maxConcurrency = Math.max(
      1,
      options.maxConcurrency ?? DEFAULT_MAX_CONCURRENCY
    );
    this._maxRetries = Math.max(1, options.maxRetries ?? DEFAULT_MAX_RETRIES);
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
   * - Retries on 429, retryable 5xx (502/503/504), and transport errors
   *   with jittered back-off
   * - Tracks rate-limit headers from every response
   */
  async fetchAsync(
    url: string | URL | Request,
    init?: RequestInit
  ): Promise<Response> {
    await this._acquireAsync();

    const route = _extractRoute(url);

    try {
      let lastResponse: Response | null = null;
      let lastError: unknown = null;

      for (let attempt = 0; attempt < this._maxRetries; attempt++) {
        await this._waitIfNeededAsync(route);

        let response: Response | null = null;
        let transportError: unknown = null;

        try {
          response = await fetch(url, init);
          this._updateFromHeaders(response.headers);
        } catch (err) {
          transportError = err;
        }

        if (response && !_isRetryableStatus(response.status)) {
          return response;
        }

        if (response) {
          lastResponse = response;
        } else {
          lastError = transportError;
        }

        const isFinalAttempt = attempt === this._maxRetries - 1;
        if (isFinalAttempt) {
          break;
        }

        const waitSec = _computeWaitSeconds(response, attempt);
        const reason = response
          ? `${response.status} on ${route}`
          : `transport error on ${route} (${_describeError(transportError)})`;
        OutputHelper.warn(
          `${reason} (attempt ${attempt + 1}/${
            this._maxRetries
          }). Retrying in ${waitSec.toFixed(1)}s...`
        );
        await new Promise((resolve) => setTimeout(resolve, waitSec * 1000));
      }

      if (lastResponse) {
        return lastResponse;
      }
      throw lastError ?? new Error(`Request to ${route} failed`);
    } finally {
      this._release();
    }
  }
}

function _isRetryableStatus(status: number): boolean {
  return status === 429 || RETRYABLE_SERVER_ERROR_STATUSES.has(status);
}

function _computeWaitSeconds(
  response: Response | null,
  attempt: number
): number {
  const retryAfter = response?.headers.get('retry-after');
  const parsed = retryAfter != null ? _parseRetryAfter(retryAfter) : null;
  // Exponential fallback capped at 30s — keeps multi-place deploys from
  // ballooning to minutes of compounded backoff while still spacing out
  // collisions when the server doesn't pin a retry-after.
  const baseSec = parsed ?? Math.min(30, Math.pow(2, attempt));
  // Additive jitter only — never wait less than retry-after asked for, but
  // desynchronize concurrent callers so they don't all retry on the exact
  // same millisecond and re-collide on the next attempt.
  return baseSec * (1 + Math.random() * RETRY_JITTER_FRACTION);
}

function _parseRetryAfter(value: string): number | null {
  const trimmed = value.trim();
  const asSeconds = Number(trimmed);
  if (Number.isFinite(asSeconds) && asSeconds >= 0) {
    return asSeconds;
  }
  const asDateMs = Date.parse(trimmed);
  if (Number.isFinite(asDateMs)) {
    return Math.max(0, (asDateMs - Date.now()) / 1000);
  }
  return null;
}

function _describeError(err: unknown): string {
  if (err instanceof Error) {
    return err.message;
  }
  return String(err);
}
