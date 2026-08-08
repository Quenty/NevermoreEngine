import { describe, it, expect, vi } from 'vitest';
import {
  runLocalWatchLoopAsync,
  type LocalWatchEntry,
} from './local-watch-loop.js';

function makeEntry(overrides: Partial<LocalWatchEntry> = {}): LocalWatchEntry {
  return {
    label: 'integration.places.hub',
    universeId: 10,
    placeId: 20,
    versionType: 'published',
    baseline: 158,
    ...overrides,
  };
}

/**
 * Drives the loop deterministically: time only advances when the loop sleeps,
 * so a test controls exactly how many poll rounds happen.
 */
function makeClock(pollIntervalMs: number) {
  let current = 0;
  return {
    now: () => current,
    sleepAsync: async () => {
      current += pollIntervalMs;
    },
  };
}

describe('runLocalWatchLoopAsync', () => {
  it('redeploys when the base place moves', async () => {
    const versions = [158, 158, 159];
    let i = 0;
    const redeployed: number[] = [];
    const clock = makeClock(1000);

    const result = await runLocalWatchLoopAsync({
      entries: [makeEntry()],
      source: {
        resolveLatestPlaceVersionAsync: async () =>
          versions[Math.min(i++, versions.length - 1)]!,
      },
      durationMs: 3000,
      pollIntervalMs: 1000,
      redeployAsync: async (_entry, version) => {
        redeployed.push(version);
      },
      ...clock,
    });

    expect(redeployed).toEqual([159]);
    expect(result.redeploys).toBe(1);
    expect(result.failures).toBe(0);
    expect(result.expired).toBe(true);
  });

  it('does not redeploy while the version holds still', async () => {
    const redeployed: number[] = [];
    const clock = makeClock(1000);

    const result = await runLocalWatchLoopAsync({
      entries: [makeEntry()],
      source: { resolveLatestPlaceVersionAsync: async () => 158 },
      durationMs: 5000,
      pollIntervalMs: 1000,
      redeployAsync: async (_e, v) => {
        redeployed.push(v);
      },
      ...clock,
    });

    expect(redeployed).toEqual([]);
    expect(result.redeploys).toBe(0);
  });

  // An entry with no lock entry has no baseline. Treating "unknown -> 158" as a
  // change would rebuild immediately on startup for no reason.
  it('adopts the first observed version when there is no baseline', async () => {
    const redeployed: number[] = [];
    const clock = makeClock(1000);

    await runLocalWatchLoopAsync({
      entries: [makeEntry({ baseline: undefined })],
      source: { resolveLatestPlaceVersionAsync: async () => 158 },
      durationMs: 3000,
      pollIntervalMs: 1000,
      redeployAsync: async (_e, v) => {
        redeployed.push(v);
      },
      ...clock,
    });

    expect(redeployed).toEqual([]);
  });

  it('keeps watching after a poll failure', async () => {
    let call = 0;
    const redeployed: number[] = [];
    const clock = makeClock(1000);

    const result = await runLocalWatchLoopAsync({
      entries: [makeEntry()],
      source: {
        resolveLatestPlaceVersionAsync: async () => {
          call++;
          if (call === 1) {
            throw new Error('ECONNRESET');
          }
          return 159;
        },
      },
      durationMs: 3000,
      pollIntervalMs: 1000,
      redeployAsync: async (_e, v) => {
        redeployed.push(v);
      },
      ...clock,
    });

    expect(redeployed).toEqual([159]);
    expect(result.redeploys).toBe(1);
  });

  // The new version is recorded only on a successful rebuild, so a transient
  // build failure is retried rather than silently skipped forever.
  it('retries a version whose rebuild failed', async () => {
    let attempts = 0;
    const clock = makeClock(1000);

    const result = await runLocalWatchLoopAsync({
      entries: [makeEntry()],
      source: { resolveLatestPlaceVersionAsync: async () => 159 },
      durationMs: 3000,
      pollIntervalMs: 1000,
      redeployAsync: async () => {
        attempts++;
        if (attempts === 1) {
          throw new Error('rojo exploded');
        }
      },
      ...clock,
    });

    expect(attempts).toBeGreaterThan(1);
    expect(result.failures).toBe(1);
    expect(result.redeploys).toBe(1);
  });

  it('stops when the caller aborts', async () => {
    const controller = new AbortController();
    const clock = makeClock(1000);
    const poll = vi.fn(async () => {
      controller.abort();
      return 158;
    });

    const result = await runLocalWatchLoopAsync({
      entries: [makeEntry()],
      source: { resolveLatestPlaceVersionAsync: poll },
      durationMs: 60_000,
      pollIntervalMs: 1000,
      redeployAsync: async () => {},
      signal: controller.signal,
      ...clock,
    });

    expect(poll).toHaveBeenCalledTimes(1);
    expect(result.expired).toBe(false);
  });

  it('watches every entry independently', async () => {
    const seen: string[] = [];
    const clock = makeClock(1000);

    await runLocalWatchLoopAsync({
      entries: [
        makeEntry({ label: 'hub', placeId: 20, baseline: 1 }),
        makeEntry({ label: 'lobby', placeId: 21, baseline: 1 }),
      ],
      source: {
        resolveLatestPlaceVersionAsync: async (_u, placeId) =>
          placeId === 21 ? 2 : 1,
      },
      durationMs: 2000,
      pollIntervalMs: 1000,
      redeployAsync: async (entry) => {
        seen.push(entry.label);
      },
      ...clock,
    });

    expect(seen).toContain('lobby');
    expect(seen).not.toContain('hub');
  });
});
