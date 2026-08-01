import { describe, it, expect, vi } from 'vitest';
import {
  type PlaceVersionSource,
  type WatchStream,
  type WatchStreamOptions,
  type WatchStreamReady,
  type WatchStreamResult,
  type WatchStreamStatus,
} from '@quenty/nevermore-deploy';
import {
  runStreamWatchLoopAsync,
  type StreamWatchEntry,
} from './stream-watch-loop.js';

/**
 * The service's version token for a Roblox place is the asset-delivery content
 * hash, not a place version — so these are deliberately not numbers. The number
 * a rebuild is made from comes from Open Cloud instead, which is what
 * `makeSource` stands in for.
 */
const TOKEN_A = 'e3b0c44298fc1c14';
const TOKEN_B = '9f86d081884c7d65';

function makeEntry(
  overrides: Partial<StreamWatchEntry> = {}
): StreamWatchEntry {
  return {
    label: 'integration.places.hub',
    watchName: 'integration.places.hub',
    universeId: 10,
    placeId: 20,
    versionType: 'published',
    ...overrides,
  };
}

function makeStatus(
  overrides: Partial<WatchStreamStatus> = {}
): WatchStreamStatus {
  return {
    name: 'integration.places.hub',
    sourceId: 'src_1',
    state: 'up-to-date',
    baselineVersion: null,
    currentVersion: null,
    ...overrides,
  };
}

function makeReady(watches: WatchStreamStatus[]): WatchStreamReady {
  return {
    type: 'ready',
    monitorId: 'mon_1',
    repository: 'Quenty/egg-hunt-2026',
    name: 'egg-hunt/integration/local',
    leaseExpiresAt: '2026-08-01T00:00:00Z',
    serverTime: '2026-07-31T00:00:00Z',
    watches,
  };
}

function makeNotify(overrides: { version?: string | null } = {}) {
  return {
    type: 'notify' as const,
    watchName: 'integration.places.hub',
    sourceId: 'src_1',
    version: TOKEN_B,
    previousVersion: TOKEN_A,
    payload: { target: 'integration.places.hub' },
    at: '2026-07-31T00:00:00Z',
    ...overrides,
  };
}

/**
 * Replays a scripted set of frames, then ends. Reconnection is the real
 * stream's job, so a script that wants to test reconciliation after a drop
 * simply delivers `ready` twice.
 */
function scriptedStream(
  script: (options: WatchStreamOptions) => Promise<void>,
  ending: WatchStreamResult['ending'] = 'aborted'
): WatchStream {
  return {
    runAsync: async (options) => {
      await script(options);
      return { ending, reconnects: 0, notifications: 0 };
    },
  };
}

function makeSource(version: number): PlaceVersionSource {
  return { resolveLatestPlaceVersionAsync: async () => version };
}

async function runAsync(
  entries: StreamWatchEntry[],
  script: (options: WatchStreamOptions) => Promise<void>,
  redeployAsync: (entry: StreamWatchEntry, version: number) => Promise<void>,
  options: {
    source?: PlaceVersionSource;
    ending?: WatchStreamResult['ending'];
  } = {}
) {
  return runStreamWatchLoopAsync({
    entries,
    stream: scriptedStream(script, options.ending ?? 'aborted'),
    source: options.source ?? makeSource(159),
    monitorId: 'mon_1',
    credential: 'token',
    signal: new AbortController().signal,
    redeployAsync,
  });
}

describe('runStreamWatchLoopAsync ready reconciliation', () => {
  // Nothing is replayed while a client is away, so `ready` is the entire
  // catch-up: a change that landed while the laptop was shut has to be found
  // by re-checking rather than by being told again.
  it('rebuilds a place that moved on while it was away', async () => {
    const built: number[] = [];

    const result = await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ currentVersion: TOKEN_B })])
        );
      },
      async (_entry, version) => {
        built.push(version);
      },
      { source: makeSource(159) }
    );

    expect(built).toEqual([159]);
    expect(result.redeploys).toBe(1);
  });

  // The service's token moving is not on its own a reason to rebuild: only the
  // place version the lock records can answer "is what I built still current".
  it('does not rebuild when the place is still at the built version', async () => {
    const built: number[] = [];

    const result = await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ currentVersion: TOKEN_B })])
        );
      },
      async (_entry, version) => {
        built.push(version);
      },
      { source: makeSource(158) }
    );

    expect(built).toEqual([]);
    expect(result.redeploys).toBe(0);
  });

  // "Never built here" is not a change. Rebuilding on it would mean every fresh
  // clone deploys once on connect, whatever the base place has been doing.
  it('adopts the current version for a place with no baseline', async () => {
    const built: number[] = [];

    await runAsync(
      [makeEntry({ baseline: undefined })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ currentVersion: TOKEN_A })])
        );
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ currentVersion: TOKEN_B })])
        );
      },
      async (_entry, version) => {
        built.push(version);
      }
    );

    expect(built).toEqual([]);
  });

  it('ignores a watch this run does not own', async () => {
    const source = vi.fn(async () => 159);

    await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([
            makeStatus({ name: 'someone-else', currentVersion: TOKEN_B }),
          ])
        );
      },
      async () => {},
      { source: { resolveLatestPlaceVersionAsync: source } }
    );

    expect(source).not.toHaveBeenCalled();
  });

  // The service not having polled yet says nothing about whether the place
  // moved, and this machine can just ask.
  it('checks anyway when the service has not polled the source yet', async () => {
    const built: number[] = [];

    await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ currentVersion: null })])
        );
      },
      async (_entry, version) => {
        built.push(version);
      },
      { source: makeSource(159) }
    );

    expect(built).toEqual([159]);
  });

  // A reconnect that reports what was already settled should cost nothing.
  it('does not re-check a token it already settled', async () => {
    const source = vi.fn(async () => 158);

    await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        for (let i = 0; i < 3; i++) {
          await options.handlers.onReadyAsync(
            makeReady([makeStatus({ currentVersion: TOKEN_A })])
          );
        }
      },
      async () => {},
      { source: { resolveLatestPlaceVersionAsync: source } }
    );

    expect(source).toHaveBeenCalledTimes(1);
  });

  // A watch left running for hours will outlive an outage; the next frame asks
  // again rather than the loop ending.
  it('survives a failure to reach Open Cloud', async () => {
    const built: number[] = [];
    let calls = 0;

    const result = await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ currentVersion: TOKEN_A })])
        );
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ currentVersion: TOKEN_B })])
        );
      },
      async (_entry, version) => {
        built.push(version);
      },
      {
        source: {
          resolveLatestPlaceVersionAsync: async () => {
            if (++calls === 1) {
              throw new Error('Open Cloud is down');
            }
            return 159;
          },
        },
      }
    );

    expect(built).toEqual([159]);
    expect(result.failures).toBe(0);
  });
});

describe('runStreamWatchLoopAsync unobservable sources', () => {
  // A private base place 401s the service's credential-free asset-delivery
  // driver. The socket says nothing about that, so without this the watch waits
  // forever on a monitor that can never fire.
  //
  // Keyed on `sourceError`, not `state`: a poll failure never moves `state`,
  // and a notify that reaches nobody counts as a successful dispatch — so an
  // unreadable place sits at "pending" indefinitely.
  it('gives up the stream when the service cannot read any of them', async () => {
    const source = vi.fn(async () => 159);

    const result = await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([
            makeStatus({
              state: 'pending',
              sourceError: 'Authentication required to access Asset.',
              sourceConsecutiveFailures: 3,
            }),
          ])
        );
        // The real stream stops here; a scripted one has to be told.
        await new Promise((resolve) => setTimeout(resolve, 5));
      },
      async () => {},
      { source: { resolveLatestPlaceVersionAsync: source } }
    );

    expect(result.unobservable).toBe(true);
    expect(source).not.toHaveBeenCalled();
  });

  // One dead place should not cost the others their hot reload.
  it('keeps streaming when only some are unreadable', async () => {
    const built: number[] = [];

    const result = await runAsync(
      [
        makeEntry({ baseline: 158 }),
        makeEntry({
          label: 'integration.places.lobby',
          watchName: 'integration.places.lobby',
          placeId: 21,
          baseline: 158,
        }),
      ],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([
            makeStatus({ sourceError: 'nope', sourceConsecutiveFailures: 3 }),
            makeStatus({
              name: 'integration.places.lobby',
              currentVersion: TOKEN_B,
            }),
          ])
        );
      },
      async (_entry, version) => {
        built.push(version);
      },
      { source: makeSource(159) }
    );

    expect(result.unobservable).toBe(false);
    expect(built).toEqual([159]);
  });
});

describe('runStreamWatchLoopAsync unobservable edge cases', () => {
  // One failed read is a blip — a rate limit, an asset-delivery hiccup — and
  // the next poll usually clears it. Abandoning the stream for that would
  // downgrade every watch to polling on a transient error.
  it('tolerates a single source failure', async () => {
    const result = await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([
            makeStatus({
              currentVersion: TOKEN_A,
              sourceError: 'timed out',
              sourceConsecutiveFailures: 1,
            }),
          ])
        );
      },
      async () => {},
      { source: makeSource(158) }
    );

    expect(result.unobservable).toBe(false);
  });

  // The monitor exists but holds none of our watches — another checkout
  // re-registered the name. Nothing can ever arrive for us, which is the same
  // silent wait by a different route.
  it('gives up when the monitor holds none of our watches', async () => {
    const result = await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ name: 'someone-elses-place' })])
        );
      },
      async () => {}
    );

    expect(result.unobservable).toBe(true);
  });
});

describe('runStreamWatchLoopAsync live poll failures', () => {
  function pollFailed(watchName: string) {
    return {
      type: 'event' as const,
      event: {
        id: 2,
        watchName,
        type: 'poll-failed',
        message: `Could not read ${watchName} after 3 attempts: Authentication required to access Asset.`,
        createdAt: '2026-07-31T00:00:00Z',
      },
    };
  }

  // A connection opened before the service's first failed poll gets a clean
  // snapshot, and the next `ready` is an hour away — so without the live tail a
  // private base place looks healthy for an hour while doing nothing.
  it('gives up when the tail reports every source unreadable', async () => {
    const result = await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ currentVersion: TOKEN_A })])
        );
        options.handlers.onEvent?.(pollFailed('integration.places.hub'));
        await new Promise((resolve) => setTimeout(resolve, 5));
      },
      async () => {},
      { source: makeSource(158) }
    );

    expect(result.unobservable).toBe(true);
  });

  it('keeps streaming while something is still readable', async () => {
    const result = await runAsync(
      [
        makeEntry({ baseline: 158 }),
        makeEntry({
          label: 'integration.places.lobby',
          watchName: 'integration.places.lobby',
          placeId: 21,
          baseline: 158,
        }),
      ],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([
            makeStatus({ currentVersion: TOKEN_A }),
            makeStatus({
              name: 'integration.places.lobby',
              currentVersion: TOKEN_A,
            }),
          ])
        );
        options.handlers.onEvent?.(pollFailed('integration.places.hub'));
        await new Promise((resolve) => setTimeout(resolve, 5));
      },
      async () => {},
      { source: makeSource(158) }
    );

    expect(result.unobservable).toBe(false);
  });

  it('ignores a poll failure for a watch this run does not own', async () => {
    const result = await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ currentVersion: TOKEN_A })])
        );
        options.handlers.onEvent?.(pollFailed('someone-elses-place'));
        await new Promise((resolve) => setTimeout(resolve, 5));
      },
      async () => {},
      { source: makeSource(158) }
    );

    expect(result.unobservable).toBe(false);
  });
});

describe('runStreamWatchLoopAsync notifications', () => {
  it('rebuilds when told the source moved', async () => {
    const built: number[] = [];

    const result = await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onNotifyAsync(makeNotify());
      },
      async (_entry, version) => {
        built.push(version);
      },
      { source: makeSource(159) }
    );

    expect(built).toEqual([159]);
    expect(result.redeploys).toBe(1);
  });

  // A `ready` covering a change and a `notify` for the same one both arrive on
  // a reconnect. Even with different tokens, the version is what decides.
  it('does not rebuild a version it already built', async () => {
    const built: number[] = [];

    await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ currentVersion: TOKEN_A })])
        );
        await options.handlers.onNotifyAsync(makeNotify({ version: TOKEN_B }));
      },
      async (_entry, version) => {
        built.push(version);
      },
      { source: makeSource(159) }
    );

    expect(built).toEqual([159]);
  });

  it('still checks when notified without a version', async () => {
    const built: number[] = [];

    await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onNotifyAsync(makeNotify({ version: null }));
      },
      async (_entry, version) => {
        built.push(version);
      },
      { source: makeSource(159) }
    );

    expect(built).toEqual([159]);
  });

  it('ignores a notification for a watch this run does not own', async () => {
    const source = vi.fn(async () => 159);

    await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onNotifyAsync({
          ...makeNotify(),
          watchName: 'someone-else',
        });
      },
      async () => {},
      { source: { resolveLatestPlaceVersionAsync: source } }
    );

    expect(source).not.toHaveBeenCalled();
  });
});

describe('runStreamWatchLoopAsync failures', () => {
  // The service advances its own baseline whether or not anyone was listening,
  // so it will never mention this change again. Leaving the watch unsettled
  // here is the only thing that gets the rebuild retried.
  it('retries on the next ready when a rebuild fails', async () => {
    const attempts: number[] = [];

    const result = await runAsync(
      [makeEntry({ baseline: 158 })],
      async (options) => {
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ currentVersion: TOKEN_B })])
        );
        await options.handlers.onReadyAsync(
          makeReady([makeStatus({ currentVersion: TOKEN_B })])
        );
      },
      async (_entry, version) => {
        attempts.push(version);
        if (attempts.length === 1) {
          throw new Error('upload exploded');
        }
      },
      { source: makeSource(159) }
    );

    expect(attempts).toEqual([159, 159]);
    expect(result.failures).toBe(1);
    expect(result.redeploys).toBe(1);
  });

  it('reports a monitor that went away', async () => {
    const result = await runAsync(
      [makeEntry({ baseline: 158 })],
      async () => {},
      async () => {},
      { ending: 'monitor-gone' }
    );

    expect(result.monitorGone).toBe(true);
  });
});
