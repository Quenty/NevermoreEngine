import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  parseWatchOption,
  type WatchNotifyAction,
  type WatchRegistrationRequest,
  type WatchRegistry,
} from '@quenty/nevermore-deploy';
import { type LocalWatchEntry } from './local-watch-loop.js';
import {
  describeNotifyWatchFallback,
  tryRegisterNotifyWatchesAsync,
} from './register-notify-watches.js';

const REGISTER_BASE = 'https://watch.example.com/v1/register/';
const watchOption = () => parseWatchOption(`${REGISTER_BASE}30m`);

beforeEach(() => {
  vi.stubEnv('GITHUB_REPOSITORY', 'Quenty/egg-hunt-2026');
  vi.stubEnv('GITHUB_REF_NAME', 'release');
  vi.stubEnv('NEVERMORE_WATCH_TOKEN', 'token-value');
});

afterEach(() => {
  vi.unstubAllEnvs();
});

function makeEntry(overrides: Partial<LocalWatchEntry> = {}): LocalWatchEntry {
  return {
    label: 'integration.places.hub',
    universeId: 10,
    placeId: 20,
    versionType: 'published',
    ...overrides,
  };
}

function makeRecordingRegistry(monitorId?: string) {
  const requests: WatchRegistrationRequest[] = [];
  const create = (): WatchRegistry => ({
    registerAsync: async (request) => {
      requests.push(request);
      return { monitorId: monitorId ?? 'mon_1', changed: true };
    },
    triggerAsync: async () => ({ results: [] }),
  });
  return { requests, create };
}

function notifyAction(
  request: WatchRegistrationRequest,
  index = 0
): WatchNotifyAction {
  const action = request.watches[index]!.action;
  expect(action.type).toBe('notify');
  return action as WatchNotifyAction;
}

describe('tryRegisterNotifyWatchesAsync', () => {
  it('registers notify actions carrying the selector', async () => {
    const registry = makeRecordingRegistry();

    const result = await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [makeEntry({ baseline: 158 })],
      createRegistry: registry.create,
    });

    expect(result.success).toBe(true);
    const request = registry.requests[0]!;
    // No baseline: the service compares its own token (an asset-delivery
    // content hash) by string equality, so the lock's Open Cloud version number
    // would read as drift on the first poll. The `ready` reconcile covers it.
    expect(request.watches[0]!.baselineVersion).toBeUndefined();
    expect(request.watches[0]!.baselineVersionKind).toBeUndefined();
    expect(request.watches[0]!.source).toEqual({
      type: 'roblox-place',
      universeId: 10,
      placeId: 20,
      versionType: 'published',
    });
    expect(notifyAction(request).payload).toEqual({
      target: 'integration.places.hub',
    });
  });

  // Re-registering replaces a monitor's whole watch list, so a local watch that
  // shared CI's monitor name would silently disarm the workflow dispatch.
  it('registers under a monitor name distinct from the dispatching one', async () => {
    const registry = makeRecordingRegistry();

    await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [makeEntry()],
      createRegistry: registry.create,
    });

    expect(registry.requests[0]!.monitorName).toBe(
      'egg-hunt/integration/local'
    );
  });

  it('hands back stream entries keyed by the registered watch name', async () => {
    const registry = makeRecordingRegistry();

    const result = await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [makeEntry()],
      createRegistry: registry.create,
    });

    expect(result.success && result.entries[0]!.watchName).toBe(
      registry.requests[0]!.watches[0]!.name
    );
    expect(result.success && result.monitorId).toBe('mon_1');
    expect(result.success && result.credential).toBe('token-value');
  });

  // Places are only optionally named, so a multi-place target with unnamed
  // places produces the same selector twice. The service resolves a duplicate
  // name by dropping a watch rather than failing.
  it('separates watches that would share a name', async () => {
    const registry = makeRecordingRegistry();

    await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [makeEntry({ placeId: 20 }), makeEntry({ placeId: 21 })],
      createRegistry: registry.create,
    });

    const names = registry.requests[0]!.watches.map((w) => w.name);
    expect(new Set(names).size).toBe(2);
    expect(names).toEqual([
      'integration.places.hub/20',
      'integration.places.hub/21',
    ]);
  });

  it('shares the Open Cloud key only when asked', async () => {
    const registry = makeRecordingRegistry();

    await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [makeEntry()],
      createRegistry: registry.create,
    });
    expect(registry.requests[0]!.robloxApiKey).toBeUndefined();

    await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [makeEntry()],
      robloxApiKey: 'secret',
      createRegistry: registry.create,
    });
    expect(registry.requests[1]!.robloxApiKey).toBe('secret');
  });
});

describe('tryRegisterNotifyWatchesAsync falling back', () => {
  // Every failure here has a working answer already — poll Open Cloud from this
  // machine — so none of them may throw.
  it('watches a "saved" place when a key is shared', async () => {
    const registry = makeRecordingRegistry();

    const result = await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [makeEntry({ versionType: 'saved', baseline: 158 })],
      robloxApiKey: 'secret',
      createRegistry: registry.create,
    });

    expect(result.success).toBe(true);
    const watch = registry.requests[0]!.watches[0]!;
    expect(watch.source.versionType).toBe('saved');
    // Same vocabulary once a key is in play, so the lock value is sendable.
    expect(watch.baselineVersion).toBe('158');
    expect(watch.baselineVersionKind).toBe('roblox-place-version');
  });

  it('declines a "saved" base place the service cannot poll', async () => {
    const registry = makeRecordingRegistry();

    const result = await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [makeEntry({ versionType: 'saved' })],
      createRegistry: registry.create,
    });

    expect(result).toMatchObject({
      success: false,
      reason: 'unwatchable_version_type',
    });
    expect(registry.requests).toEqual([]);
  });

  // Splitting the run — streaming the published places and polling the saved
  // one — would leave two watch loops disagreeing about what is current.
  it('declines the whole run when only some places are unwatchable', async () => {
    const result = await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [
        makeEntry({ label: 'integration.places.hub' }),
        makeEntry({ label: 'integration.places.lobby', versionType: 'saved' }),
      ],
      createRegistry: makeRecordingRegistry().create,
    });

    expect(result).toMatchObject({ success: false });
    expect(
      result.success === false && describeNotifyWatchFallback(result)
    ).toMatch(/integration\.places\.lobby/);
  });

  it('declines without a token, since registration has no identity', async () => {
    vi.stubEnv('NEVERMORE_WATCH_TOKEN', '');
    vi.stubEnv('GITHUB_TOKEN', '');

    const result = await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [makeEntry()],
      createRegistry: makeRecordingRegistry().create,
    });

    expect(result).toMatchObject({ success: false, reason: 'no_token' });
  });

  it('declines when the service refuses the registration', async () => {
    const result = await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [makeEntry()],
      createRegistry: () => ({
        registerAsync: async () => {
          throw new Error('503 Service Unavailable');
        },
        triggerAsync: async () => ({ results: [] }),
      }),
    });

    expect(result).toMatchObject({
      success: false,
      reason: 'register_failed',
    });
    expect(
      result.success === false && describeNotifyWatchFallback(result)
    ).toMatch(/503 Service Unavailable/);
  });

  it('declines when the service returns no monitor to stream', async () => {
    const result = await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [makeEntry()],
      createRegistry: () => ({
        registerAsync: async () => ({ changed: true }),
        triggerAsync: async () => ({ results: [] }),
      }),
    });

    expect(result).toMatchObject({ success: false, reason: 'no_monitor_id' });
  });

  it('declines when there is nothing to watch', async () => {
    const result = await tryRegisterNotifyWatchesAsync({
      option: watchOption(),
      monitorName: 'egg-hunt/integration',
      entries: [],
      createRegistry: makeRecordingRegistry().create,
    });

    expect(result).toMatchObject({ success: false, reason: 'no_entries' });
  });
});
