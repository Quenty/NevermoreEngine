import { describe, it, expect } from 'vitest';
import { type WatchRegistrationRequest } from '@quenty/nevermore-deploy';
import { HttpWatchRegistry } from './http-watch-registry.js';

const REGISTER_URL = 'https://watch.example.com/v1/register/7d/';

function makeRequest(
  overrides: Partial<WatchRegistrationRequest> = {}
): WatchRegistrationRequest {
  return {
    monitorName: 'integration',
    repository: 'Quenty/egg-hunt-2026',
    githubToken: 'token-value',
    watches: [
      {
        name: 'quenty/hub/hub',
        source: {
          type: 'roblox-place',
          universeId: 10,
          placeId: 20,
          versionType: 'published',
        },
        baselineVersion: '158',
        baselineVersionKind: 'roblox-place-version',
        action: {
          type: 'github-workflow-dispatch',
          workflow: '.github/workflows/build.yml',
          ref: 'main',
          inputs: { target: 'integration.places.hub' },
        },
      },
    ],
    ...overrides,
  };
}

function makeResponse(
  body: string,
  init: { status?: number; statusText?: string } = {}
): Response {
  return {
    ok: (init.status ?? 200) < 400,
    status: init.status ?? 200,
    statusText: init.statusText ?? 'OK',
    text: async () => body,
  } as Response;
}

function registryReturning(
  response: Response,
  calls?: Array<{ url: string; init: RequestInit }>
): HttpWatchRegistry {
  return new HttpWatchRegistry({
    registerUrl: REGISTER_URL,
    fetchImpl: (async (url: string, init: RequestInit) => {
      calls?.push({ url, init });
      return response;
    }) as unknown as typeof fetch,
  });
}

describe('HttpWatchRegistry', () => {
  it('posts a MonitorRequest to the register URL', async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    await registryReturning(makeResponse('{}'), calls).registerAsync(
      makeRequest()
    );

    expect(calls).toHaveLength(1);
    expect(calls[0]!.url).toBe(REGISTER_URL);
    expect(calls[0]!.init.method).toBe('POST');

    expect(JSON.parse(calls[0]!.init.body as string)).toEqual({
      name: 'integration',
      auth: {
        github: {
          token: 'token-value',
          repository: 'Quenty/egg-hunt-2026',
        },
      },
      watches: [
        {
          name: 'quenty/hub/hub',
          source: {
            type: 'roblox-place',
            universeId: 10,
            placeId: 20,
            versionType: 'published',
          },
          baselineVersion: '158',
          baselineVersionKind: 'roblox-place-version',
          action: {
            type: 'github-workflow-dispatch',
            workflow: '.github/workflows/build.yml',
            ref: 'main',
            inputs: { target: 'integration.places.hub' },
          },
        },
      ],
    });
  });

  it('sends every watch in one request', async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    const base = makeRequest();
    await registryReturning(makeResponse('{}'), calls).registerAsync({
      ...base,
      watches: [base.watches[0]!, { ...base.watches[0]!, name: 'pkg/lobby' }],
    });

    expect(calls).toHaveLength(1);
    expect(JSON.parse(calls[0]!.init.body as string).watches).toHaveLength(2);
  });

  it('omits the Open Cloud key unless one was shared', async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    await registryReturning(makeResponse('{}'), calls).registerAsync(
      makeRequest()
    );

    expect(JSON.parse(calls[0]!.init.body as string).auth).not.toHaveProperty(
      'robloxOpenCloud'
    );
  });

  it('includes the Open Cloud key when shared', async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    await registryReturning(makeResponse('{}'), calls).registerAsync(
      makeRequest({ robloxApiKey: 'oc-key' })
    );

    expect(
      JSON.parse(calls[0]!.init.body as string).auth.robloxOpenCloud
    ).toEqual({ apiKey: 'oc-key' });
  });

  // The kind describes the value, so sending it alone would declare the
  // vocabulary of a baseline that is not there.
  it('omits the declared kind along with the baseline', async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    const base = makeRequest();
    await registryReturning(makeResponse('{}'), calls).registerAsync({
      ...base,
      watches: [{ ...base.watches[0]!, baselineVersion: undefined }],
    });

    expect(
      JSON.parse(calls[0]!.init.body as string).watches[0]
    ).not.toHaveProperty('baselineVersionKind');
  });

  it('omits baselineVersion when there is no baseline', async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    const base = makeRequest();
    await registryReturning(makeResponse('{}'), calls).registerAsync({
      ...base,
      watches: [{ ...base.watches[0]!, baselineVersion: undefined }],
    });

    expect(
      JSON.parse(calls[0]!.init.body as string).watches[0]
    ).not.toHaveProperty('baselineVersion');
  });

  it('reads back the monitor the service reports', async () => {
    const result = await registryReturning(
      makeResponse(
        JSON.stringify({
          monitorId: 'mon_9f2a',
          revision: 'abc123',
          leaseExpiresAt: '2026-08-06T00:00:00Z',
          changed: true,
          watches: [{ name: 'a' }, { name: 'b' }],
          unexpected: 'ignored',
        })
      )
    ).registerAsync(makeRequest());

    expect(result).toEqual({
      monitorId: 'mon_9f2a',
      revision: 'abc123',
      leaseExpiresAt: '2026-08-06T00:00:00Z',
      changed: true,
      watchCount: 2,
    });
  });

  it('reports an unchanged re-apply', async () => {
    const result = await registryReturning(
      makeResponse(JSON.stringify({ monitorId: 'mon_1', changed: false }))
    ).registerAsync(makeRequest());

    expect(result.changed).toBe(false);
  });

  it('treats a 2xx with an unusable body as registered without details', async () => {
    expect(
      await registryReturning(makeResponse('not json')).registerAsync(
        makeRequest()
      )
    ).toEqual({});
  });

  describe('failure messages', () => {
    it('leads with the service message and adds our remedy on 401', async () => {
      await expect(
        registryReturning(
          makeResponse(JSON.stringify({ error: 'bad credentials' }), {
            status: 401,
            statusText: 'Unauthorized',
          })
        ).registerAsync(makeRequest())
      ).rejects.toThrowError(/^bad credentials\nSet NEVERMORE_WATCH_TOKEN/);
    });

    it('falls back to our own wording when the service says nothing', async () => {
      await expect(
        registryReturning(
          makeResponse('', { status: 401, statusText: 'Unauthorized' })
        ).registerAsync(makeRequest())
      ).rejects.toThrowError(/^GitHub rejected the dispatch token\./);
    });

    it('names the repository and required scope on 403', async () => {
      await expect(
        registryReturning(
          makeResponse('', { status: 403, statusText: 'Forbidden' })
        ).registerAsync(makeRequest())
      ).rejects.toThrowError(
        /cannot write to Quenty\/egg-hunt-2026.*actions: write/s
      );
    });

    it('explains a quota failure on 409', async () => {
      await expect(
        registryReturning(
          makeResponse('', { status: 409, statusText: 'Conflict' })
        ).registerAsync(makeRequest())
      ).rejects.toThrowError(/quota exceeded for Quenty\/egg-hunt-2026/);
    });

    it('lists the workflows it referenced on 422', async () => {
      await expect(
        registryReturning(
          makeResponse('', { status: 422, statusText: 'Unprocessable Entity' })
        ).registerAsync(makeRequest())
      ).rejects.toThrowError(
        /workflow does not exist.*\.github\/workflows\/build\.yml/s
      );
    });

    // Observed against prod: a notify-only monitor was refused 422 because the
    // Open Cloud key lacked a scope, and the reply appended "Referenced: ." plus
    // advice about a workflow path — under a message that had nothing to do with
    // workflows. 422 now covers several causes and the service names which.
    it('adds no workflow advice when the monitor dispatches none', async () => {
      const request = makeRequest();
      request.watches = request.watches.map((watch) => ({
        ...watch,
        action: { type: 'notify' as const, payload: { target: 'x' } },
      }));

      await expect(
        registryReturning(
          makeResponse(
            JSON.stringify({
              error: 'The Open Cloud key is not allowed to read place 1 (403).',
            }),
            { status: 422, statusText: 'Unprocessable Entity' }
          )
        ).registerAsync(request)
      ).rejects.toThrowError(/not allowed to read place 1/);

      await expect(
        registryReturning(
          makeResponse(JSON.stringify({ error: 'nope' }), {
            status: 422,
            statusText: 'Unprocessable Entity',
          })
        ).registerAsync(request)
      ).rejects.not.toThrowError(/Referenced|workflow/);
    });

    it('surfaces the API error body', async () => {
      await expect(
        registryReturning(
          makeResponse(JSON.stringify({ error: 'lease too long' }), {
            status: 400,
            statusText: 'Bad Request',
          })
        ).registerAsync(makeRequest())
      ).rejects.toThrowError(/lease too long/);
    });

    it('includes the API validation detail list', async () => {
      await expect(
        registryReturning(
          makeResponse(
            JSON.stringify({
              error: "request/body must have required property 'name'",
              errors: [{ path: '/body/name', errorCode: 'required' }],
            }),
            { status: 400, statusText: 'Bad Request' }
          )
        ).registerAsync(makeRequest())
      ).rejects.toThrowError(/\/body\/name/);
    });

    it('falls back to status text on an unmapped code', async () => {
      await expect(
        registryReturning(
          makeResponse('', { status: 503, statusText: 'Service Unavailable' })
        ).registerAsync(makeRequest())
      ).rejects.toThrowError(/503 Service Unavailable/);
    });

    it('reports the endpoint when the request cannot be made', async () => {
      const registry = new HttpWatchRegistry({
        registerUrl: REGISTER_URL,
        fetchImpl: (async () => {
          throw new Error('ENOTFOUND');
        }) as unknown as typeof fetch,
      });

      await expect(registry.registerAsync(makeRequest())).rejects.toThrowError(
        /could not reach https:\/\/watch\.example\.com/
      );
    });
  });
});
