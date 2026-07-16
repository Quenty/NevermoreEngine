import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

vi.mock('@quenty/cli-output-helpers', () => ({
  OutputHelper: {
    warn: vi.fn(),
    info: vi.fn(),
    error: vi.fn(),
  },
}));

import { RateLimiter } from './rate-limiter.js';

interface Deferred<T> {
  promise: Promise<T>;
  resolve: (value: T) => void;
}

function deferred<T>(): Deferred<T> {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((res) => {
    resolve = res;
  });
  return { promise, resolve };
}

function makeResponse(
  status: number,
  headers: Record<string, string> = {}
): Response {
  return new Response(null, { status, headers });
}

// Yields back through the event loop so any pending microtask chains in the
// limiter (await acquire → await waitIfNeeded → await fetch) get to dispatch.
function flushMicrotasksAsync(): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

describe('RateLimiter', () => {
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
    // Pin jitter so retry waits are exactly baseSec — otherwise we can't
    // assert on a single advanceTimersByTime value.
    vi.spyOn(Math, 'random').mockReturnValue(0);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('caps in-flight requests at maxConcurrency and dispatches queued callers on release', async () => {
    const limiter = new RateLimiter({ maxConcurrency: 2 });
    const gates = [
      deferred<Response>(),
      deferred<Response>(),
      deferred<Response>(),
    ];
    let callIndex = 0;
    fetchMock.mockImplementation(() => gates[callIndex++]!.promise);

    const p1 = limiter.fetchAsync('https://apis.roblox.com/cloud/v2/a');
    const p2 = limiter.fetchAsync('https://apis.roblox.com/cloud/v2/b');
    const p3 = limiter.fetchAsync('https://apis.roblox.com/cloud/v2/c');

    await flushMicrotasksAsync();
    expect(fetchMock).toHaveBeenCalledTimes(2);

    gates[0]!.resolve(makeResponse(200));
    await p1;
    await flushMicrotasksAsync();
    expect(fetchMock).toHaveBeenCalledTimes(3);

    gates[1]!.resolve(makeResponse(200));
    gates[2]!.resolve(makeResponse(200));
    await Promise.all([p2, p3]);
  });

  it('retries on 429 honoring retry-after before returning the eventual 200', async () => {
    vi.useFakeTimers();
    const limiter = new RateLimiter();

    fetchMock
      .mockResolvedValueOnce(makeResponse(429, { 'retry-after': '5' }))
      .mockResolvedValueOnce(makeResponse(200));

    const promise = limiter.fetchAsync('https://apis.roblox.com/cloud/v2/a');

    // First attempt fires immediately
    await vi.advanceTimersByTimeAsync(0);
    expect(fetchMock).toHaveBeenCalledTimes(1);

    // Mid-wait: still only one call
    await vi.advanceTimersByTimeAsync(4999);
    expect(fetchMock).toHaveBeenCalledTimes(1);

    // Crossing the retry-after boundary releases the retry
    await vi.advanceTimersByTimeAsync(1);
    const response = await promise;
    expect(response.status).toBe(200);
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('blocks the next request when x-ratelimit-remaining hits 0 until reset elapses', async () => {
    vi.useFakeTimers();
    const limiter = new RateLimiter();

    fetchMock
      .mockResolvedValueOnce(
        makeResponse(200, {
          'x-ratelimit-remaining': '0',
          'x-ratelimit-reset': '5',
        })
      )
      .mockResolvedValueOnce(makeResponse(200));

    await limiter.fetchAsync('https://apis.roblox.com/cloud/v2/a');
    expect(fetchMock).toHaveBeenCalledTimes(1);

    const second = limiter.fetchAsync('https://apis.roblox.com/cloud/v2/b');

    // Without advancing time, the second fetch is parked in _waitIfNeededAsync
    await vi.advanceTimersByTimeAsync(0);
    expect(fetchMock).toHaveBeenCalledTimes(1);

    await vi.advanceTimersByTimeAsync(5000);
    await second;
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('returns the last 429 response after exhausting all retries without sleeping past the final attempt', async () => {
    vi.useFakeTimers();
    const limiter = new RateLimiter({ maxRetries: 3 });

    fetchMock.mockResolvedValue(makeResponse(429, { 'retry-after': '1' }));

    const promise = limiter.fetchAsync('https://apis.roblox.com/cloud/v2/a');

    // Two backoffs between three attempts. After the third failure the
    // limiter must return immediately rather than sleeping pointlessly.
    await vi.advanceTimersByTimeAsync(1000);
    await vi.advanceTimersByTimeAsync(1000);

    const response = await promise;
    expect(response.status).toBe(429);
    expect(fetchMock).toHaveBeenCalledTimes(3);
  });

  it('retries on 503 with backoff before returning success', async () => {
    vi.useFakeTimers();
    const limiter = new RateLimiter();

    fetchMock
      .mockResolvedValueOnce(makeResponse(503))
      .mockResolvedValueOnce(makeResponse(200));

    const promise = limiter.fetchAsync('https://apis.roblox.com/cloud/v2/a');

    await vi.advanceTimersByTimeAsync(0);
    expect(fetchMock).toHaveBeenCalledTimes(1);

    // Exponential fallback for attempt 0 is 2^0 = 1s.
    await vi.advanceTimersByTimeAsync(1000);
    const response = await promise;
    expect(response.status).toBe(200);
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('retries on transport errors and surfaces the last error if all attempts reject', async () => {
    vi.useFakeTimers();
    const limiter = new RateLimiter({ maxRetries: 2 });

    fetchMock.mockRejectedValue(new TypeError('ECONNRESET'));

    const promise = limiter.fetchAsync('https://apis.roblox.com/cloud/v2/a');
    const settled = promise.catch((err) => err);

    await vi.advanceTimersByTimeAsync(1000);

    const err = await settled;
    expect(err).toBeInstanceOf(TypeError);
    expect((err as Error).message).toBe('ECONNRESET');
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('does not retry on non-retryable 4xx responses', async () => {
    const limiter = new RateLimiter();
    fetchMock.mockResolvedValueOnce(makeResponse(404));

    const response = await limiter.fetchAsync(
      'https://apis.roblox.com/cloud/v2/a'
    );
    expect(response.status).toBe(404);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('retries a transient HTML edge 400 but not a structured JSON API 400', async () => {
    // A large upload can trip an edge proxy that answers 400 with an HTML body
    // — transient framing noise we should ride out. A genuine Open Cloud 400 is
    // a JSON error and must be returned immediately, not retried.
    vi.useFakeTimers();
    const limiter = new RateLimiter();

    // Edge 400 (text/html) then success — must retry.
    fetchMock
      .mockResolvedValueOnce(makeResponse(400, { 'content-type': 'text/html' }))
      .mockResolvedValueOnce(makeResponse(200));

    const edge = limiter.fetchAsync('https://apis.roblox.com/cloud/v2/a');
    await vi.advanceTimersByTimeAsync(0);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(1000); // 2^0 = 1s backoff
    expect((await edge).status).toBe(200);
    expect(fetchMock).toHaveBeenCalledTimes(2);

    fetchMock.mockClear();

    // API 400 (application/json) — must NOT retry.
    fetchMock.mockResolvedValueOnce(
      makeResponse(400, { 'content-type': 'application/json' })
    );
    const api = await limiter.fetchAsync('https://apis.roblox.com/cloud/v2/b');
    expect(api.status).toBe(400);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});
