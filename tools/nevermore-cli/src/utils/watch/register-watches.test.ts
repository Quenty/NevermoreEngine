import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import {
  BasePlaceResolver,
  parseWatchOption,
  resolveDeployLockPath,
  saveDeployLockAsync,
  type DeployTarget,
  type WatchRegistrationRequest,
  type WatchRegistry,
  type WatchWorkflowDispatchAction,
} from '@quenty/nevermore-deploy';
import {
  registerWatchesAsync,
  type WatchCandidate,
} from './register-watches.js';

/** No endpoint ships with the CLI, so tests supply their own. */
const REGISTER_BASE = 'https://watch.example.com/v1/register/';
const watchOption = () => parseWatchOption(`${REGISTER_BASE}7d`);

/**
 * This path only ever builds dispatching watches, so a recorded action that is
 * anything else is itself the failure — asserted rather than cast past.
 */
function dispatchAction(
  request: WatchRegistrationRequest,
  index = 0
): WatchWorkflowDispatchAction {
  const action = request.watches[index]!.action;
  expect(action.type).toBe('github-workflow-dispatch');
  return action as WatchWorkflowDispatchAction;
}

/** Answers from the lock only; the network source is never the right baseline. */
function makeResolver(): BasePlaceResolver {
  return new BasePlaceResolver({
    source: {
      resolveLatestPlaceVersionAsync: async () => {
        throw new Error('a baseline must come from the lock, not the network');
      },
    },
  });
}

let packageDir: string;

beforeEach(async () => {
  packageDir = await fs.mkdtemp(path.join(os.tmpdir(), 'register-watches-'));
  vi.stubEnv('GITHUB_REPOSITORY', 'Quenty/egg-hunt-2026');
  vi.stubEnv('GITHUB_REF_NAME', 'release');
  vi.stubEnv('NEVERMORE_WATCH_TOKEN', 'token-value');
});

afterEach(async () => {
  vi.unstubAllEnvs();
  await fs.rm(packageDir, { recursive: true, force: true });
});

function makePlace(overrides: Partial<DeployTarget> = {}): DeployTarget {
  return {
    name: 'hub',
    universeId: 1,
    placeId: 2,
    project: 'default.project.json',
    watch: '.github/workflows/build.yml',
    basePlace: { universeId: 10, placeId: 20, version: 'published' },
    ...overrides,
  };
}

function makeCandidate(
  overrides: Partial<WatchCandidate> = {}
): WatchCandidate {
  return {
    targetName: 'integration',
    packageName: '@quenty/egg-hunt-hub',
    packagePath: packageDir,
    place: makePlace(),
    ...overrides,
  };
}

/** Fills in the parts of the port a given test does not care about. */
function fakeRegistry(
  partial: Partial<WatchRegistry>
): (registerUrl: string) => WatchRegistry {
  return () => ({
    registerAsync: async () => ({}),
    triggerAsync: async () => ({ results: [] }),
    ...partial,
  });
}

function makeRecordingRegistry() {
  const requests: WatchRegistrationRequest[] = [];
  return {
    requests,
    create: fakeRegistry({
      registerAsync: async (request: WatchRegistrationRequest) => {
        requests.push(request);
        return {
          monitorId: 'mon_1',
          leaseExpiresAt: '2026-08-06T00:00:00Z',
          changed: true,
        };
      },
    }),
  };
}

async function writeLockAsync(placeId: number, version: number) {
  await saveDeployLockAsync(resolveDeployLockPath(packageDir), {
    lockfileVersion: 1,
    basePlaces: { [String(placeId)]: { version, from: 'published' } },
  });
}

describe('registerWatchesAsync', () => {
  it('registers one monitor holding every watch', async () => {
    const registry = makeRecordingRegistry();
    await writeLockAsync(20, 158);

    const result = await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [
        makeCandidate({ place: makePlace({ name: 'hub' }) }),
        makeCandidate({ place: makePlace({ name: 'lobby' }) }),
      ],
      createRegistry: registry.create,
    });

    expect(result).toEqual({ registered: 2, changed: true });
    expect(registry.requests).toHaveLength(1);

    const request = registry.requests[0]!;
    expect(request.monitorName).toBe('integration/release');
    expect(request.repository).toBe('Quenty/egg-hunt-2026');
    expect(request.githubToken).toBe('token-value');
    expect(request.watches).toEqual([
      {
        name: 'quenty/egg-hunt-hub/hub',
        source: {
          type: 'roblox-place',
          universeId: 10,
          placeId: 20,
          versionType: 'published',
        },
        action: {
          type: 'github-workflow-dispatch',
          workflow: '.github/workflows/build.yml',
          ref: 'release',
          inputs: { target: 'integration.places.hub' },
        },
      },
      {
        name: 'quenty/egg-hunt-hub/lobby',
        source: {
          type: 'roblox-place',
          universeId: 10,
          placeId: 20,
          versionType: 'published',
        },
        action: {
          type: 'github-workflow-dispatch',
          workflow: '.github/workflows/build.yml',
          ref: 'release',
          inputs: { target: 'integration.places.lobby' },
        },
      },
    ]);
  });

  // Regression: the selector was previously re-appended to a target name that
  // already carried one, producing `integration.places.hub.places.hub` — which
  // the dispatched `deploy run` then could not resolve, killing the reload.
  it('does not re-append a place to a selector that already names one', async () => {
    const registry = makeRecordingRegistry();

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [makeCandidate({ targetName: 'integration.places.hub' })],
      createRegistry: registry.create,
    });

    expect(dispatchAction(registry.requests[0]!).inputs).toEqual({
      target: 'integration.places.hub',
    });
  });

  it('puts the ref in the monitor name so branches cannot collide', async () => {
    const registry = makeRecordingRegistry();

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [makeCandidate()],
      createRegistry: registry.create,
    });

    // GITHUB_REF_NAME is stubbed to "release" for these tests.
    expect(registry.requests[0]!.monitorName).toBe('integration/release');
    expect(dispatchAction(registry.requests[0]!).ref).toBe('release');
  });

  it('refuses to register from a pull request merge ref', async () => {
    vi.stubEnv('GITHUB_REF_NAME', '42/merge');

    await expect(
      registerWatchesAsync({
        option: watchOption(),
        monitorName: 'integration',
        resolver: makeResolver(),
        candidates: [makeCandidate()],
        createRegistry: fakeRegistry({}),
      })
    ).rejects.toThrowError(/pull request merge ref/);
  });

  // Places are only optionally named, so a multi-place target can collide by
  // construction. The service resolves duplicates its own way, which silently
  // drops a watch.
  it('disambiguates watch names that would otherwise collide', async () => {
    const registry = makeRecordingRegistry();

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [
        makeCandidate({
          place: makePlace({
            name: undefined,
            basePlace: { universeId: 10, placeId: 20, version: 'published' },
          }),
        }),
        makeCandidate({
          place: makePlace({
            name: undefined,
            basePlace: { universeId: 10, placeId: 21, version: 'published' },
          }),
        }),
      ],
      createRegistry: registry.create,
    });

    const names = registry.requests[0]!.watches.map((w) => w.name);
    expect(names).toEqual([
      'quenty/egg-hunt-hub/integration/20',
      'quenty/egg-hunt-hub/integration/21',
    ]);
    expect(new Set(names).size).toBe(2);
  });

  // The service refuses "saved" at registration until it has a credentialed
  // driver. That refusal would fail the whole request — every watch in the
  // monitor — so it has to be filtered before sending, not sent and rejected.
  it('leaves out a "saved" pin without dropping its siblings', async () => {
    const registry = makeRecordingRegistry();

    const result = await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [
        makeCandidate({
          place: makePlace({
            name: 'studio',
            basePlace: { universeId: 10, placeId: 20, version: 'saved' },
          }),
        }),
        makeCandidate({ place: makePlace({ name: 'hub' }) }),
      ],
      createRegistry: registry.create,
    });

    expect(result.registered).toBe(1);
    expect(registry.requests[0]!.watches.map((w) => w.name)).toEqual([
      'quenty/egg-hunt-hub/hub',
    ]);
  });

  it('sends the version type an omitted pin resolves to', async () => {
    const registry = makeRecordingRegistry();

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [
        makeCandidate({
          place: makePlace({ basePlace: { universeId: 10, placeId: 20 } }),
        }),
      ],
      createRegistry: registry.create,
    });

    expect(registry.requests[0]!.watches[0]!.source.versionType).toBe(
      'published'
    );
  });

  it('leaves distinct watch names untouched', async () => {
    const registry = makeRecordingRegistry();

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [
        makeCandidate({ place: makePlace({ name: 'hub' }) }),
        makeCandidate({ place: makePlace({ name: 'lobby' }) }),
      ],
      createRegistry: registry.create,
    });

    expect(registry.requests[0]!.watches.map((w) => w.name)).toEqual([
      'quenty/egg-hunt-hub/hub',
      'quenty/egg-hunt-hub/lobby',
    ]);
  });

  it('strips the npm scope marker from names the service would reject', async () => {
    const registry = makeRecordingRegistry();

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: '@quenty/egg-hunt-hub/integration',
      resolver: makeResolver(),
      candidates: [makeCandidate()],
      createRegistry: registry.create,
    });

    expect(registry.requests[0]!.monitorName).toBe(
      'quenty/egg-hunt-hub/integration/release'
    );
    expect(registry.requests[0]!.watches[0]!.name).toBe(
      'quenty/egg-hunt-hub/hub'
    );
  });

  // Reading anonymously, the service compares asset-delivery content hashes, and
  // the lock's Open Cloud version number could only ever look like drift —
  // dispatching a rebuild of what was just built. Omitting makes the first poll
  // adopt what is there.
  it('sends no baseline when no key is shared', async () => {
    const registry = makeRecordingRegistry();
    await writeLockAsync(20, 42);

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [makeCandidate()],
      createRegistry: registry.create,
    });

    expect(registry.requests[0]!.watches[0]!.baselineVersion).toBeUndefined();
    expect(
      registry.requests[0]!.watches[0]!.baselineVersionKind
    ).toBeUndefined();
  });

  // With a key the service reads version history and answers in place versions
  // — the same language the lock is written in — so a baseline finally means
  // what it says.
  it('sends the lock baseline, declared, when a key is shared', async () => {
    const registry = makeRecordingRegistry();
    await writeLockAsync(20, 42);

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      robloxApiKey: 'secret',
      candidates: [makeCandidate()],
      createRegistry: registry.create,
    });

    expect(registry.requests[0]!.watches[0]!.baselineVersion).toBe('42');
    expect(registry.requests[0]!.watches[0]!.baselineVersionKind).toBe(
      'roblox-place-version'
    );
  });

  // This is what a baseline is for in a batch: a package that did not deploy
  // this run still has a lock entry, and without it the first poll would adopt
  // current and never notice the change that already happened.
  it('takes the baseline from the lock, never the network', async () => {
    const registry = makeRecordingRegistry();
    await writeLockAsync(20, 42);

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      robloxApiKey: 'secret',
      candidates: [makeCandidate()],
      createRegistry: registry.create,
    });

    // makeResolver throws if anything reaches for the network.
    expect(registry.requests[0]!.watches[0]!.baselineVersion).toBe('42');
  });

  it('omits the baseline when the lock has no entry for the place', async () => {
    const registry = makeRecordingRegistry();

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      robloxApiKey: 'secret',
      candidates: [makeCandidate()],
      createRegistry: registry.create,
    });

    expect(registry.requests[0]!.watches[0]!.baselineVersion).toBeUndefined();
  });

  it('registers nothing when no place is watchable', async () => {
    const registry = makeRecordingRegistry();

    const result = await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [makeCandidate({ place: makePlace({ watch: undefined }) })],
      createRegistry: registry.create,
    });

    expect(result).toEqual({ registered: 0 });
    expect(registry.requests).toEqual([]);
  });

  it('leaves out a place whose base place is pinned to an exact version', async () => {
    const registry = makeRecordingRegistry();

    const result = await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [
        makeCandidate({
          place: makePlace({
            basePlace: { universeId: 10, placeId: 20, version: 158 },
          }),
        }),
      ],
      createRegistry: registry.create,
    });

    expect(result).toEqual({ registered: 0 });
    expect(registry.requests).toEqual([]);
  });

  it('keeps watchable places when a sibling is not watchable', async () => {
    const registry = makeRecordingRegistry();

    const result = await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [
        makeCandidate({ place: makePlace({ name: 'hub' }) }),
        makeCandidate({
          place: makePlace({ name: 'lobby', watch: undefined }),
        }),
      ],
      createRegistry: registry.create,
    });

    expect(result.registered).toBe(1);
    expect(registry.requests[0]!.watches.map((w) => w.name)).toEqual([
      'quenty/egg-hunt-hub/hub',
    ]);
  });

  it('shares the Open Cloud key only when given one', async () => {
    const registry = makeRecordingRegistry();

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [makeCandidate()],
      createRegistry: registry.create,
    });
    expect(registry.requests[0]!.robloxApiKey).toBeUndefined();

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      robloxApiKey: 'oc-key',
      candidates: [makeCandidate()],
      createRegistry: registry.create,
    });
    expect(registry.requests[1]!.robloxApiKey).toBe('oc-key');
  });

  it('reports an unchanged re-apply', async () => {
    const result = await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [makeCandidate()],
      createRegistry: fakeRegistry({
        registerAsync: async () => ({ changed: false }),
      }),
    });

    expect(result).toEqual({ registered: 1, changed: false });
  });

  describe('triggerAfterRegister', () => {
    it('fires the monitor after registering', async () => {
      const triggered: Array<{ monitorId: string; credential: string }> = [];

      const result = await registerWatchesAsync({
        option: watchOption(),
        monitorName: 'integration',
        resolver: makeResolver(),
        candidates: [makeCandidate()],
        triggerAfterRegister: true,
        createRegistry: fakeRegistry({
          registerAsync: async () => ({ monitorId: 'mon_7' }),
          triggerAsync: async (monitorId, credential) => {
            triggered.push({ monitorId, credential });
            return { results: [{ watchName: 'w', ok: true }] };
          },
        }),
      });

      expect(triggered).toEqual([
        { monitorId: 'mon_7', credential: 'token-value' },
      ]);
      expect(result.triggered).toBe(1);
    });

    it('does not fire unless asked', async () => {
      const trigger = vi.fn(async () => ({ results: [] }));

      const result = await registerWatchesAsync({
        option: watchOption(),
        monitorName: 'integration',
        resolver: makeResolver(),
        candidates: [makeCandidate()],
        createRegistry: fakeRegistry({
          registerAsync: async () => ({ monitorId: 'mon_7' }),
          triggerAsync: trigger,
        }),
      });

      expect(trigger).not.toHaveBeenCalled();
      expect(result.triggered).toBeUndefined();
    });

    // The monitor exists and is worth keeping; only the demonstration failed.
    it('keeps the registration when the forced dispatch fails', async () => {
      const result = await registerWatchesAsync({
        option: watchOption(),
        monitorName: 'integration',
        resolver: makeResolver(),
        candidates: [makeCandidate()],
        triggerAfterRegister: true,
        createRegistry: fakeRegistry({
          registerAsync: async () => ({ monitorId: 'mon_7' }),
          triggerAsync: async () => {
            throw new Error('service said no');
          },
        }),
      });

      expect(result.registered).toBe(1);
      expect(result.triggered).toBeUndefined();
    });

    it('counts only the watches that actually dispatched', async () => {
      const result = await registerWatchesAsync({
        option: watchOption(),
        monitorName: 'integration',
        resolver: makeResolver(),
        candidates: [makeCandidate()],
        triggerAfterRegister: true,
        createRegistry: fakeRegistry({
          registerAsync: async () => ({ monitorId: 'mon_7' }),
          triggerAsync: async () => ({
            results: [
              { watchName: 'a', ok: true },
              { watchName: 'b', ok: false, detail: 'workflow missing' },
            ],
          }),
        }),
      });

      expect(result.triggered).toBe(1);
    });
  });

  it('uses the explicit register URL when one was given', async () => {
    const urls: string[] = [];

    await registerWatchesAsync({
      option: parseWatchOption('https://watch.example.com/v1/register/2w/'),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [makeCandidate()],
      createRegistry: (url) => {
        urls.push(url);
        return fakeRegistry({})(url);
      },
    });

    expect(urls).toEqual(['https://watch.example.com/v1/register/2w/']);
  });

  it('fails when there is no repository to dispatch', async () => {
    // An absent GITHUB_REPOSITORY falls back to the "origin" remote, so the
    // only way to have no repository is to also be outside a git checkout.
    // The temp package dir is exactly that.
    const originalCwd = process.cwd();
    vi.stubEnv('GITHUB_REPOSITORY', '');
    process.chdir(packageDir);

    try {
      await expect(
        registerWatchesAsync({
          option: watchOption(),
          monitorName: 'integration',
          resolver: makeResolver(),
          candidates: [makeCandidate()],
          createRegistry: fakeRegistry({}),
        })
      ).rejects.toThrowError(/GitHub repository/);
    } finally {
      process.chdir(originalCwd);
    }
  });

  it('falls back to the origin remote when GITHUB_REPOSITORY is unset', async () => {
    const registry = makeRecordingRegistry();
    vi.stubEnv('GITHUB_REPOSITORY', '');

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [makeCandidate()],
      createRegistry: registry.create,
    });

    // Resolved from this repo's own remote, whatever it is named.
    expect(registry.requests[0]!.repository).toMatch(/^[\w.-]+\/[\w.-]+$/);
  });

  // An unset CI secret expands to "" rather than being absent, so the fallback
  // has to treat empty as missing or it never fires.
  it('falls back to GITHUB_TOKEN when the watch token is set but empty', async () => {
    const registry = makeRecordingRegistry();
    vi.stubEnv('NEVERMORE_WATCH_TOKEN', '');
    vi.stubEnv('GITHUB_TOKEN', 'fallback-token');

    await registerWatchesAsync({
      option: watchOption(),
      monitorName: 'integration',
      resolver: makeResolver(),
      candidates: [makeCandidate()],
      createRegistry: registry.create,
    });

    expect(registry.requests[0]!.githubToken).toBe('fallback-token');
  });

  it('fails when there is no token to dispatch with', async () => {
    vi.stubEnv('NEVERMORE_WATCH_TOKEN', '');
    vi.stubEnv('GITHUB_TOKEN', '');

    await expect(
      registerWatchesAsync({
        option: watchOption(),
        monitorName: 'integration',
        resolver: makeResolver(),
        candidates: [makeCandidate()],
        createRegistry: fakeRegistry({}),
      })
    ).rejects.toThrowError(/No GitHub token found/);
  });
});
