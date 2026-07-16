import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import * as fs from 'fs/promises';
import { OpenCloudClient } from './open-cloud-client.js';
import type { RateLimiter } from './rate-limiter.js';

vi.mock('@quenty/cli-output-helpers', () => ({
  OutputHelper: {
    verbose: vi.fn(),
    warn: vi.fn(),
    formatDim: (s: string) => s,
    formatInfo: (s: string) => s,
    formatError: (s: string) => s,
    formatWarning: (s: string) => s,
  },
}));

vi.mock('fs/promises', () => ({ readFile: vi.fn() }));

describe('OpenCloudClient.uploadPlaceAsync', () => {
  beforeEach(() => {
    vi.mocked(fs.readFile).mockResolvedValue(
      Buffer.from([1, 2, 3, 4, 5]) as unknown as string
    );
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('streams the upload via an injected fetch impl and reports byte-level progress', async () => {
    // The upload streams its body through node-fetch (injected as fetchImpl):
    // undici cannot send a streaming request body to the Open Cloud endpoint on
    // Node 24 ("expected non-null body source"), so the limiter must drive the
    // Node-http-based client. The body is handed over as a per-attempt factory
    // so each retry gets a fresh, un-disturbed stream; a counting Transform on
    // it drives byte-level progress. Content-Length is set so it isn't chunked.
    let capturedInit: RequestInit | undefined;
    let capturedFetchImpl: unknown;
    const fakeLimiter = {
      fetchAsync: vi.fn(
        async (
          _url: string | URL,
          init?: RequestInit | (() => RequestInit),
          options?: { fetchImpl?: unknown }
        ) => {
          capturedInit = typeof init === 'function' ? init() : init;
          capturedFetchImpl = options?.fetchImpl;
          // Drain the streaming body so the counting Transform fires progress,
          // exactly as the real transport would as it sends bytes.
          const body = capturedInit?.body as AsyncIterable<Uint8Array>;
          for await (const _chunk of body) {
            void _chunk;
          }
          return new Response(JSON.stringify({ versionNumber: 7 }), {
            status: 200,
          });
        }
      ),
    } as unknown as RateLimiter;

    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: fakeLimiter,
    });

    const progress: Array<[number, number]> = [];
    const version = await client.uploadPlaceAsync(
      1,
      2,
      '/tmp/place.rbxl',
      false,
      (transferred, total) => progress.push([transferred, total])
    );

    expect(version).toBe(7);
    // A dedicated fetch impl (node-fetch) is injected, not the global default.
    expect(typeof capturedFetchImpl).toBe('function');
    // Content-Length pins the length so node-fetch doesn't chunk the upload.
    const headers = capturedInit?.headers as Record<string, string>;
    expect(headers['Content-Length']).toBe('5');
    // Byte-level progress: an initial 0, then cumulative up to the full size.
    expect(progress[0]).toEqual([0, 5]);
    expect(progress[progress.length - 1]).toEqual([5, 5]);
  });

  it('marks the version Published only when publish is true', async () => {
    const urls: string[] = [];
    const fakeLimiter = {
      fetchAsync: vi.fn(
        async (url: string | URL, init?: RequestInit | (() => RequestInit)) => {
          urls.push(String(url));
          // Drain the streamed body so the upload's Transform can complete.
          const resolved = typeof init === 'function' ? init() : init;
          const body = resolved?.body as AsyncIterable<Uint8Array> | undefined;
          if (body) {
            for await (const _chunk of body) {
              void _chunk;
            }
          }
          return new Response(JSON.stringify({ versionNumber: 1 }), {
            status: 200,
          });
        }
      ),
    } as unknown as RateLimiter;

    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: fakeLimiter,
    });

    await client.uploadPlaceAsync(1, 2, '/tmp/place.rbxl', true);
    await client.uploadPlaceAsync(1, 2, '/tmp/place.rbxl', false);

    expect(urls[0]).toContain('versionType=Published');
    expect(urls[1]).toContain('versionType=Saved');
  });
});
