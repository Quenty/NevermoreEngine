import { OutputHelper } from '@quenty/cli-output-helpers';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';

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

const ID_SEGMENT_PATTERN =
  /^(\d+|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i;

/**
 * Identifies the quota a request draws from. Open Cloud meters each endpoint
 * separately (task creation: 5/min, task polling: 200/min, …), so the key is
 * the method plus the path with ids collapsed — every poll of every task
 * shares one bucket, and it is not the bucket task creation uses.
 */
function _bucketKey(url: string | URL | Request, init?: RequestInit): string {
  try {
    const urlStr =
      typeof url === 'string' ? url : url instanceof URL ? url.href : url.url;
    const parsed = new URL(urlStr);
    const path = parsed.pathname
      .split('/')
      .map((segment) => (ID_SEGMENT_PATTERN.test(segment) ? ':id' : segment))
      .join('/');
    const method = (init?.method ?? 'GET').toUpperCase();
    return `${method} ${parsed.host}${path}`;
  } catch {
    return 'unknown';
  }
}

/** A wait the limiter is about to sleep through before sending a request. */
export interface RateLimitWait {
  route: string;
  waitMs: number;
  /**
   * `quota`: a prior response said this endpoint's quota is spent.
   * `retry`: this request failed (429, 5xx, transport) and is backing off.
   */
  reason: 'quota' | 'retry';
  /** HTTP status that triggered a `retry` wait, absent for transport errors. */
  status?: number;
}

/**
 * Builds an `onWait` that shows the wait as the package's progress label, so
 * a spinner stuck on "Scheduling" reads as rate limiting rather than a hang.
 */
export function reportRateLimitWait(
  reporter: Reporter,
  packageName: string
): (wait: RateLimitWait) => void {
  return (wait) => {
    reporter.onPackageProgressUpdate(packageName, {
      kind: 'steps',
      completed: 0,
      total: 0,
      label: formatRateLimitWait(wait),
    });
  };
}

/**
 * Kept short enough that "◇ Scheduling (…)" fits the spinner's 32-column
 * status cell: a longer label wraps on an 80-column terminal, and the
 * spinner's cursor rewind doesn't count wrapped lines. The `--verbose`
 * warnings carry the status code and route.
 */
export function formatRateLimitWait(wait: RateLimitWait): string {
  if (wait.reason === 'quota') {
    return `rate limited ${Math.ceil(wait.waitMs / 1000)}s`;
  }
  const waitSec = Math.round(wait.waitMs / 1000);
  if (wait.status === 429) {
    return `rate limited ${waitSec}s`;
  }
  return `retrying in ${waitSec}s`;
}

interface QuotaState {
  remaining: number | null;
  resetAtMs: number | null;
}

/**
 * Minimal fetch shape the limiter drives. Defaults to the global `fetch`
 * (undici). Callers can inject an alternative — e.g. node-fetch, whose Node
 * `http` stack accepts a streaming request body against the Open Cloud upload
 * endpoint where undici throws "expected non-null body source".
 */
export type FetchLike = (
  url: string | URL | Request,
  init?: RequestInit
) => Promise<Response>;

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
 *   per endpoint, so a spent task-creation quota doesn't stall task polling
 * - Caps concurrent in-flight requests (default 4) via a semaphore so callers
 *   benefit from parallelism (e.g. multi-place deploys) while still getting
 *   header feedback before each wave widens past the quota
 * - Retries on 429 with exponential back-off plus 0-30% additive jitter so
 *   concurrent callers don't all wake up on the same millisecond and re-collide
 */
export class RateLimiter {
  private _quotas = new Map<string, QuotaState>();

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

  private _updateFromHeaders(
    bucketKey: string,
    route: string,
    status: number,
    headers: Headers
  ): void {
    const remaining = headers.get('x-ratelimit-remaining');
    const reset = headers.get('x-ratelimit-reset');

    const rateLimitHeaders: string[] = [];
    headers.forEach((value, key) => {
      if (key.toLowerCase().includes('ratelimit') || key === 'retry-after') {
        rateLimitHeaders.push(`${key}=${value}`);
      }
    });
    OutputHelper.verbose(
      `[rate-limit] ${status} ${route} ${
        rateLimitHeaders.join(' ') || '(no rate-limit headers)'
      }`
    );

    if (remaining === null && reset === null) {
      return;
    }

    let quota = this._quotas.get(bucketKey);
    if (!quota) {
      quota = { remaining: null, resetAtMs: null };
      this._quotas.set(bucketKey, quota);
    }

    if (remaining !== null) {
      quota.remaining = parseInt(remaining, 10);
    }

    // x-ratelimit-reset is seconds until reset, not an epoch timestamp
    if (reset !== null) {
      const resetSec = parseFloat(reset);
      quota.resetAtMs = Date.now() + resetSec * 1000;
    }
  }

  private async _waitIfNeededAsync(
    bucketKey: string,
    route: string,
    onWait?: (wait: RateLimitWait) => void
  ): Promise<void> {
    const quota = this._quotas.get(bucketKey);
    if (
      quota &&
      quota.remaining !== null &&
      quota.remaining <= 0 &&
      quota.resetAtMs !== null
    ) {
      const waitMs = quota.resetAtMs - Date.now();
      if (waitMs > 0) {
        const waitSec = Math.ceil(waitMs / 1000);
        OutputHelper.warn(
          `Rate limit reached on ${route}. Waiting ${waitSec}s (Roblox requested)...`
        );
        onWait?.({ route, waitMs, reason: 'quota' });
        await new Promise((resolve) => setTimeout(resolve, waitMs));
      }
      // Reset after waiting so the next request can proceed
      this._quotas.delete(bucketKey);
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
   * - Tells `onWait` before every sleep, so callers can say why they stalled
   */
  async fetchAsync(
    url: string | URL | Request,
    init?: RequestInit | (() => RequestInit),
    options?: {
      fetchImpl?: FetchLike;
      onWait?: (wait: RateLimitWait) => void;
    }
  ): Promise<Response> {
    await this._acquireAsync();

    const route = _extractRoute(url);
    const doFetch = options?.fetchImpl ?? fetch;
    const onWait = options?.onWait;

    try {
      let lastResponse: Response | null = null;
      let lastError: unknown = null;

      for (let attempt = 0; attempt < this._maxRetries; attempt++) {
        // Resolve init per attempt so a caller streaming a one-shot body
        // (e.g. a progress-reporting upload) hands us a fresh, un-disturbed
        // stream on every retry; a reused stream throws "body ... disturbed
        // or locked". Plain-object inits (Uint8Array/string bodies) are just
        // returned as-is and replay safely.
        const resolvedInit = typeof init === 'function' ? init() : init;
        const bucketKey = _bucketKey(url, resolvedInit);
        await this._waitIfNeededAsync(bucketKey, route, onWait);

        let response: Response | null = null;
        let transportError: unknown = null;

        try {
          response = await doFetch(url, resolvedInit);
          this._updateFromHeaders(
            bucketKey,
            route,
            response.status,
            response.headers
          );
        } catch (err) {
          transportError = err;
        }

        if (response && !_isRetryableResponse(response)) {
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
        onWait?.({
          route,
          waitMs: waitSec * 1000,
          reason: 'retry',
          status: response?.status,
        });
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

function _isRetryableResponse(response: Response): boolean {
  const { status } = response;
  if (status === 429 || RETRYABLE_SERVER_ERROR_STATUSES.has(status)) {
    return true;
  }
  // 408 Request Timeout is transient by definition.
  if (status === 408) {
    return true;
  }
  // A large upload occasionally trips an edge/proxy that answers 400 with an
  // HTML body ("Your browser sent an invalid request") — transient framing
  // noise, not the API rejecting the payload. A genuine Open Cloud 400 comes
  // back as a structured JSON error and must NOT be retried, so gate on the
  // content type: retry a 400 only when it isn't application/json.
  if (status === 400) {
    const contentType = response.headers.get('content-type') ?? '';
    return !contentType.toLowerCase().includes('application/json');
  }
  return false;
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
