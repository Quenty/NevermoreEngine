import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import * as fs from 'fs/promises';
import {
  OpenCloudClient,
  getTaskReturnValues,
  type LuauTask,
} from './open-cloud-client.js';
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

describe('OpenCloudClient.downloadPlaceAsync', () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it('downloads the latest version when no version is pinned', async () => {
    const urls: string[] = [];
    const fakeLimiter = {
      fetchAsync: vi.fn(async (url: string | URL) => {
        urls.push(String(url));
        return new Response(JSON.stringify({ location: 'https://cdn/x' }), {
          status: 200,
        });
      }),
    } as unknown as RateLimiter;
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response(Buffer.from([1, 2, 3]), { status: 200 }))
    );

    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: fakeLimiter,
    });
    const buffer = await client.downloadPlaceAsync(1, 22);

    expect(urls[0]).toBe(
      'https://apis.roblox.com/asset-delivery-api/v1/assetId/22'
    );
    expect(urls[0]).not.toContain('/version/');
    expect([...buffer]).toEqual([1, 2, 3]);
  });

  it('downloads a specific version when pinned', async () => {
    const urls: string[] = [];
    const fakeLimiter = {
      fetchAsync: vi.fn(async (url: string | URL) => {
        urls.push(String(url));
        return new Response(JSON.stringify({ location: 'https://cdn/x' }), {
          status: 200,
        });
      }),
    } as unknown as RateLimiter;
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response(Buffer.from([9]), { status: 200 }))
    );

    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: fakeLimiter,
    });
    await client.downloadPlaceAsync(1, 22, undefined, 42);

    expect(urls[0]).toBe(
      'https://apis.roblox.com/asset-delivery-api/v1/assetId/22/version/42'
    );
  });

  it('throws a clear error when a pinned version does not exist', async () => {
    // The Asset Delivery API reports a missing version as HTTP 200 with an
    // errors array and no location.
    const fakeLimiter = {
      fetchAsync: vi.fn(
        async () =>
          new Response(
            JSON.stringify({
              errors: [{ code: 404, message: 'Request asset was not found' }],
            }),
            { status: 200 }
          )
      ),
    } as unknown as RateLimiter;

    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: fakeLimiter,
    });

    await expect(
      client.downloadPlaceAsync(1, 22, undefined, 999999)
    ).rejects.toThrowError(/no version 999999/);
  });
});

describe('OpenCloudClient.resolveLatestPlaceVersionAsync', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  /** Page the Assets API newest-first, as the real endpoint does. */
  function makeVersionsLimiter(
    pages: Array<Array<{ version: number; published?: boolean }>>,
    urls: string[] = []
  ): RateLimiter {
    return {
      fetchAsync: vi.fn(async (url: string | URL) => {
        urls.push(String(url));
        const page = pages[urls.length - 1] ?? [];
        return new Response(
          JSON.stringify({
            assetVersions: page.map((entry) => ({
              path: `assets/22/versions/${entry.version}`,
              // The real API omits `published` entirely on save-only versions.
              ...(entry.published ? { published: true } : {}),
            })),
            ...(urls.length < pages.length
              ? { nextPageToken: `token-${urls.length}` }
              : {}),
          }),
          { status: 200 }
        );
      }),
    } as unknown as RateLimiter;
  }

  it('resolves "saved" to the newest version of any kind', async () => {
    const urls: string[] = [];
    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: makeVersionsLimiter(
        [[{ version: 5781 }, { version: 5780, published: true }]],
        urls
      ),
    });

    expect(await client.resolveLatestPlaceVersionAsync(1, 22, 'saved')).toBe(
      5781
    );
    expect(urls).toHaveLength(1);
    expect(urls[0]).toBe(
      'https://apis.roblox.com/assets/v1/assets/22/versions?maxPageSize=50'
    );
  });

  it('resolves "published" past unpublished saves at the head', async () => {
    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: makeVersionsLimiter([
        [
          { version: 5781 },
          { version: 5780 },
          { version: 5779, published: true },
        ],
      ]),
    });

    expect(
      await client.resolveLatestPlaceVersionAsync(1, 22, 'published')
    ).toBe(5779);
  });

  it('pages only until the newest published version is found', async () => {
    const urls: string[] = [];
    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: makeVersionsLimiter(
        [
          [{ version: 300 }, { version: 299 }],
          [{ version: 298, published: true }, { version: 297 }],
          [{ version: 296, published: true }],
        ],
        urls
      ),
    });

    expect(
      await client.resolveLatestPlaceVersionAsync(1, 22, 'published')
    ).toBe(298);
    expect(urls).toHaveLength(2);
    expect(urls[1]).toContain('pageToken=token-1');
  });

  it('throws when the place has never been published', async () => {
    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: makeVersionsLimiter([[{ version: 2 }, { version: 1 }]]),
    });

    await expect(
      client.resolveLatestPlaceVersionAsync(1, 22, 'published')
    ).rejects.toThrowError(/no published version/);
  });

  it('refuses to guess when the API stops paging newest-first', async () => {
    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: makeVersionsLimiter([
        [{ version: 1 }, { version: 2, published: true }],
      ]),
    });

    await expect(
      client.resolveLatestPlaceVersionAsync(1, 22, 'published')
    ).rejects.toThrowError(/no longer paging newest-first/);
  });

  it('refuses a "saved" lookup when the page is not newest-first', async () => {
    // "saved" answers from the first entry, so the ordering guard has to check
    // the whole page before returning or this silently pins the oldest build.
    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: makeVersionsLimiter([
        [{ version: 1 }, { version: 2 }, { version: 3 }],
      ]),
    });

    await expect(
      client.resolveLatestPlaceVersionAsync(1, 22, 'saved')
    ).rejects.toThrowError(/no longer paging newest-first/);
  });

  it('reports the scan limit when every page is unpublished', async () => {
    const pages = Array.from({ length: 25 }, (_, page) =>
      Array.from({ length: 2 }, (_, i) => ({ version: 1000 - page * 2 - i }))
    );
    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: makeVersionsLimiter(pages),
    });

    await expect(
      client.resolveLatestPlaceVersionAsync(1, 22, 'published')
    ).rejects.toThrowError(/in its most recent 1000 versions/);
  });

  it('throws on an unparseable version path', async () => {
    const fakeLimiter = {
      fetchAsync: vi.fn(
        async () =>
          new Response(
            JSON.stringify({
              assetVersions: [{ path: 'assets/22/versions/' }],
            }),
            { status: 200 }
          )
      ),
    } as unknown as RateLimiter;

    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: fakeLimiter,
    });

    await expect(
      client.resolveLatestPlaceVersionAsync(1, 22, 'saved')
    ).rejects.toThrowError(/unparseable version path/);
  });
});

describe('getTaskReturnValues', () => {
  function makeTask(overrides: Partial<LuauTask>): LuauTask {
    return {
      path: 'universes/1/places/2/versions/3/luau-execution-session-tasks/4',
      createTime: '2026-01-01T00:00:00Z',
      updateTime: '2026-01-01T00:01:00Z',
      user: 'users/1',
      state: 'COMPLETE',
      script: 'return 1',
      ...overrides,
    };
  }

  it('returns the values natively typed, one entry per returned value', () => {
    // Roblox serializes the return value itself, so a returned table arrives as
    // real nested JSON — there is no JSON string to parse a second time.
    const task = makeTask({
      output: {
        results: [{ slug: 'maid', counts: { passed: 1014 } }, 'str', 42, true],
      },
    });

    expect(getTaskReturnValues(task)).toEqual([
      { slug: 'maid', counts: { passed: 1014 } },
      'str',
      42,
      true,
    ]);
  });

  it('reports an empty result when the task returned nothing', () => {
    expect(getTaskReturnValues(makeTask({ output: {} }))).toEqual([]);
  });

  it('reports undefined when a failed task carried no output at all', () => {
    // An oversize return value fails the task with no output and no error
    // message, so "nothing came back to read" has to stay distinguishable from
    // "the script returned nothing" — only the former can fall back to logs.
    const task = makeTask({ state: 'FAILED', output: undefined });

    expect(getTaskReturnValues(task)).toBeUndefined();
  });
});

describe('OpenCloudClient.getRawTaskLogsAsync', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  /**
   * Page the logs endpoint the way the real one does: many messages inside each
   * `luauExecutionSessionTaskLog`, and pagination over those entries rather than
   * over messages.
   */
  function makeLogsLimiter(
    pages: Array<Array<string[]>>,
    urls: string[] = []
  ): RateLimiter {
    return {
      fetchAsync: vi.fn(async (url: string | URL) => {
        urls.push(String(url));
        const page = pages[urls.length - 1] ?? [];
        return new Response(
          JSON.stringify({
            luauExecutionSessionTaskLogs: page.map((messages) => ({
              structuredMessages: messages.map((message) => ({
                message,
                createTime: '2026-08-27T00:00:00.38Z',
                messageType: 'OUTPUT',
              })),
            })),
            ...(urls.length < pages.length
              ? { nextPageToken: `token-${urls.length}` }
              : {}),
          }),
          { status: 200 }
        );
      }),
    } as unknown as RateLimiter;
  }

  it('counts pages, entries and messages separately', async () => {
    // Entries are not lines: the endpoint's page size applies to the log
    // objects, each of which carries many messages. Conflating the two reads a
    // 2-entry response as a 2-line run.
    const client = new OpenCloudClient({
      apiKey: 'test-key',
      rateLimiter: makeLogsLimiter([[['a', 'b', 'c'], ['d']], [['e', 'f']]]),
    });

    const fetched = await client.getRawTaskLogsAsync('universes/1/tasks/2');

    expect(fetched.text).toBe('a\nb\nc\nd\ne\nf');
    expect(fetched.stats).toEqual({
      requests: 2,
      pages: 2,
      entries: 3,
      messages: 6,
      chars: 11,
    });
  });

  it('counts every attempt when empty logs were retried', async () => {
    // The retry is invisible in the text it eventually returns, so a run whose
    // logs only showed up on the third ask looks exactly like one that answered
    // immediately. It is the difference between a slow API and a silent run.
    vi.spyOn(global, 'setTimeout').mockImplementation((fn: () => void) => {
      fn();
      return 0 as unknown as NodeJS.Timeout;
    });

    // One unpaged response per attempt: two empty, then the logs. A limiter
    // that pages would fold all three into a single attempt and prove nothing.
    let attempt = 0;
    const rateLimiter = {
      fetchAsync: vi.fn(async () => {
        attempt++;
        return new Response(
          JSON.stringify({
            luauExecutionSessionTaskLogs:
              attempt < 3
                ? []
                : [
                    {
                      structuredMessages: [
                        {
                          message: 'late',
                          createTime: '2026-08-27T00:00:00.38Z',
                          messageType: 'OUTPUT',
                        },
                      ],
                    },
                  ],
          }),
          { status: 200 }
        );
      }),
    } as unknown as RateLimiter;

    const client = new OpenCloudClient({ apiKey: 'test-key', rateLimiter });

    const fetched = await client.getRawTaskLogsAsync('universes/1/tasks/2');

    expect(fetched.text).toBe('late');
    expect(fetched.stats.requests).toBe(3);
    expect(fetched.stats.pages).toBe(1);
    expect(fetched.stats.messages).toBe(1);
  });
});
