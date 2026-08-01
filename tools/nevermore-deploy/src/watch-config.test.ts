import { describe, it, expect } from 'vitest';
import { type DeployTarget } from './deploy-config.js';
import {
  buildWatchMonitorName,
  buildWatchPlan,
  parseWatchDuration,
  parseWatchOption,
  resolveWatchDelivery,
  sanitizeWatchName,
} from './watch-config.js';

const DAY_MS = 24 * 60 * 60 * 1000;

function makePlace(overrides: Partial<DeployTarget> = {}): DeployTarget {
  return {
    universeId: 1,
    placeId: 2,
    project: 'default.project.json',
    ...overrides,
  };
}

describe('parseWatchDuration', () => {
  it('parses each supported unit', () => {
    expect(parseWatchDuration('90s')).toBe(90 * 1000);
    expect(parseWatchDuration('30m')).toBe(30 * 60 * 1000);
    expect(parseWatchDuration('12h')).toBe(12 * 60 * 60 * 1000);
    expect(parseWatchDuration('7d')).toBe(7 * DAY_MS);
    expect(parseWatchDuration('2w')).toBe(14 * DAY_MS);
  });

  it('rejects a missing unit', () => {
    expect(() => parseWatchDuration('7')).toThrowError(
      /Invalid watch duration/
    );
  });

  it('rejects an unknown unit', () => {
    expect(() => parseWatchDuration('7y')).toThrowError(
      /Invalid watch duration/
    );
  });

  it('rejects zero', () => {
    expect(() => parseWatchDuration('0d')).toThrowError(/greater than zero/);
  });
});

const BASE_URL = 'https://watch.example.com/v1/register/';

describe('parseWatchOption', () => {
  it('takes the endpoint as given and reads its lease', () => {
    expect(parseWatchOption(`${BASE_URL}7d/`)).toEqual({
      registerUrl: `${BASE_URL}7d/`,
      lease: '7d',
      durationMs: 7 * DAY_MS,
    });
  });

  it('accepts a URL with no trailing slash', () => {
    expect(parseWatchOption('https://example.com/v1/register/12h').lease).toBe(
      '12h'
    );
  });

  it('accepts the uppercase lease spelling the API allows', () => {
    expect(parseWatchOption('https://example.com/v1/register/2W').lease).toBe(
      '2W'
    );
  });

  it('accepts a plaintext endpoint', () => {
    expect(
      parseWatchOption('http://localhost:3002/v1/register/30m').lease
    ).toBe('30m');
  });

  // A bare duration would need a host to compose onto, and this package is
  // published from a public repo that must never carry one — so the endpoint is
  // named at the call site rather than defaulted or read from the environment.
  it('refuses a bare duration, and says what to pass instead', () => {
    expect(() => parseWatchOption('7d')).toThrowError(
      /takes the register endpoint URL/
    );
    expect(() => parseWatchOption('7d')).toThrowError(/v1\/register\/7d/);
  });

  it('refuses anything else that is not a URL', () => {
    expect(() => parseWatchOption('soon')).toThrowError(
      /takes the register endpoint URL/
    );
  });

  // The API takes the lease from the path, so a URL without one is a 400
  // waiting to happen — after a deploy has already shipped.
  it('rejects a URL whose path does not end in a lease', () => {
    expect(() =>
      parseWatchOption('https://example.com/v1/register')
    ).toThrowError(/does not end in a lease/);
  });

  it('rejects a URL ending in a bare number', () => {
    expect(() =>
      parseWatchOption('https://example.com/v1/register/7/')
    ).toThrowError(/does not end in a lease/);
  });
});

describe('sanitizeWatchName', () => {
  it('drops a leading npm scope marker', () => {
    expect(sanitizeWatchName('@quenty/egg-hunt-hub')).toBe(
      'quenty/egg-hunt-hub'
    );
  });

  it('keeps the characters the service allows', () => {
    expect(sanitizeWatchName('quenty/egg-hunt.hub_2/integration')).toBe(
      'quenty/egg-hunt.hub_2/integration'
    );
  });

  it('replaces disallowed characters rather than dropping them', () => {
    // Dropping would collapse "a b" and "ab" onto one name.
    expect(sanitizeWatchName('pkg name!')).toBe('pkg-name-');
  });

  it('truncates to the service maximum, keeping the distinguishing tail', () => {
    const name = sanitizeWatchName('x'.repeat(120) + '/hub');
    expect(name).toHaveLength(100);
    expect(name.endsWith('/hub')).toBe(true);
  });

  it('rejects a name with nothing usable in it', () => {
    expect(() => sanitizeWatchName('@')).toThrowError(
      /Cannot derive a watch name/
    );
  });
});

describe('buildWatchPlan', () => {
  it('plans a place that has both watch and basePlace', () => {
    const place = makePlace({
      name: 'hub',
      watch: '.github/workflows/build.yml',
      basePlace: { universeId: 10, placeId: 20 },
    });

    const plan = buildWatchPlan('integration', [place]);

    expect(plan.skipped).toEqual([]);
    expect(plan.entries).toEqual([
      {
        selector: 'integration.places.hub',
        workflow: '.github/workflows/build.yml',
      },
    ]);
  });

  it('uses a bare target name for an unnamed place', () => {
    const plan = buildWatchPlan('production', [
      makePlace({
        watch: '.github/workflows/build.yml',
        basePlace: { universeId: 10, placeId: 20 },
      }),
    ]);

    expect(plan.entries[0]!.selector).toBe('production');
  });

  it('skips a place with no watch field', () => {
    const plan = buildWatchPlan('integration', [
      makePlace({ name: 'hub', basePlace: { universeId: 10, placeId: 20 } }),
    ]);

    expect(plan.entries).toEqual([]);
    expect(plan.skipped).toEqual([
      { selector: 'integration.places.hub', reason: 'no-watch-field' },
    ]);
  });

  it('skips a watch with nothing to watch for', () => {
    const plan = buildWatchPlan('integration', [
      makePlace({ name: 'hub', watch: '.github/workflows/build.yml' }),
    ]);

    expect(plan.entries).toEqual([]);
    expect(plan.skipped).toEqual([
      { selector: 'integration.places.hub', reason: 'no-base-place' },
    ]);
  });

  it('skips a base place pinned to an exact version', () => {
    const plan = buildWatchPlan('integration', [
      makePlace({
        name: 'hub',
        watch: '.github/workflows/build.yml',
        basePlace: { universeId: 10, placeId: 20, version: 158 },
      }),
    ]);

    expect(plan.entries).toEqual([]);
    expect(plan.skipped).toEqual([
      { selector: 'integration.places.hub', reason: 'pinned-base-place' },
    ]);
  });

  it('watches a base place tracking published', () => {
    const plan = buildWatchPlan('integration', [
      makePlace({
        name: 'hub',
        watch: '.github/workflows/build.yml',
        basePlace: { universeId: 10, placeId: 20, version: 'published' },
      }),
    ]);

    expect(plan.entries).toHaveLength(1);
    expect(plan.skipped).toEqual([]);
  });

  // Reading anonymously, the service sees asset delivery, which reports
  // published content only — it refuses "saved" at registration, and one
  // refusal fails the whole request, taking every unrelated watch with it.
  it('skips a "saved" base place when no key is shared', () => {
    const plan = buildWatchPlan('integration', [
      makePlace({
        name: 'hub',
        watch: '.github/workflows/build.yml',
        basePlace: { universeId: 10, placeId: 20, version: 'saved' },
      }),
    ]);

    expect(plan.entries).toEqual([]);
    expect(plan.skipped).toEqual([
      { selector: 'integration.places.hub', reason: 'saved-needs-api-key' },
    ]);
  });

  // A shared Open Cloud key selects a credentialed driver that reads version
  // history, which is where a saved-but-unpublished version is visible at all.
  it('watches a "saved" base place when a key is shared', () => {
    const plan = buildWatchPlan(
      'integration',
      [
        makePlace({
          name: 'hub',
          watch: '.github/workflows/build.yml',
          basePlace: { universeId: 10, placeId: 20, version: 'saved' },
        }),
      ],
      { credentialed: true }
    );

    expect(plan.skipped).toEqual([]);
    expect(plan.entries).toHaveLength(1);
  });

  // A key changes what can be *seen*, not what it means to hold a version
  // still. A numeric pin is still the opposite of watching.
  it('still skips an exact pin even with a key', () => {
    const plan = buildWatchPlan(
      'integration',
      [
        makePlace({
          name: 'hub',
          watch: '.github/workflows/build.yml',
          basePlace: { universeId: 10, placeId: 20, version: 158 },
        }),
      ],
      { credentialed: true }
    );

    expect(plan.skipped).toEqual([
      { selector: 'integration.places.hub', reason: 'pinned-base-place' },
    ]);
  });

  it('partitions a mixed multi-place target', () => {
    const watched = makePlace({
      name: 'hub',
      watch: '.github/workflows/build.yml',
      basePlace: { universeId: 10, placeId: 20 },
    });
    const plan = buildWatchPlan('integration', [
      watched,
      makePlace({ name: 'lobby' }),
    ]);

    expect(plan.entries.map((e) => e.selector)).toEqual([
      'integration.places.hub',
    ]);
    expect(plan.skipped.map((s) => s.selector)).toEqual([
      'integration.places.lobby',
    ]);
  });
});

describe('buildWatchMonitorName', () => {
  it('scopes the name to the package and target', () => {
    expect(
      buildWatchMonitorName({
        packageName: 'egg-hunt-2026',
        targetName: 'demo',
      })
    ).toBe('egg-hunt-2026/demo');
  });

  it('gives a dryrun its own name', () => {
    const real = buildWatchMonitorName({
      packageName: 'egg-hunt-2026',
      targetName: 'demo',
    });
    const dryrun = buildWatchMonitorName({
      packageName: 'egg-hunt-2026',
      targetName: 'demo',
      dryrun: true,
    });

    expect(dryrun).not.toBe(real);
    expect(dryrun).toBe('egg-hunt-2026/demo/dryrun');
  });

  it('gives every caller registering one package the same name', () => {
    // The point of the function. `deploy run` knows the package it is in and
    // `batch deploy` discovers it, but a monitor is keyed by name — so two
    // spellings would be two monitors on one base place, dispatching twice per
    // publish and racing each other's lock write.
    const fromDeployRun = buildWatchMonitorName({
      packageName: '@quenty/hub',
      targetName: 'demo',
    });
    const fromBatch = buildWatchMonitorName({
      packageName: '@quenty/hub',
      targetName: 'demo',
    });

    expect(fromBatch).toBe(fromDeployRun);
  });
});

describe('resolveWatchDelivery', () => {
  it('dispatches when automated and notifies when not', () => {
    expect(resolveWatchDelivery('auto', true)).toBe('dispatch');
    expect(resolveWatchDelivery('auto', false)).toBe('notify');
    expect(resolveWatchDelivery(undefined, true)).toBe('dispatch');
    expect(resolveWatchDelivery(undefined, false)).toBe('notify');
  });

  it('lets an explicit mode override detection either way', () => {
    // The reachable half. An automated context that is not GitHub Actions
    // detects as local, and notifying there holds a stream nothing will close:
    // no error, no output, just a job burning its timeout.
    expect(resolveWatchDelivery('dispatch', false)).toBe('dispatch');
    expect(resolveWatchDelivery('notify', true)).toBe('notify');
  });
});
