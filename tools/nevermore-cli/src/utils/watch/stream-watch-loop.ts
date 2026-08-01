import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type PlaceVersionSource,
  type WatchStream,
  type WatchStreamNotify,
  type WatchStreamReady,
  type WatchStreamStatus,
} from '@quenty/nevermore-deploy';
import { type LocalWatchEntry } from './local-watch-loop.js';

/**
 * Whether the service has actually failed to read this source, as opposed to
 * simply not having polled it yet.
 *
 * One failure is a blip — an asset-delivery hiccup, a rate limit — and the next
 * poll usually clears it. Requiring the service's own consecutive counter to
 * have moved keeps a transient error from abandoning a working stream.
 */
function _isUnreadable(status: WatchStreamStatus): boolean {
  return (
    status.sourceError != null && (status.sourceConsecutiveFailures ?? 0) > 1
  );
}

/** A locally-watched place, paired with the watch name it was registered under. */
export interface StreamWatchEntry extends LocalWatchEntry {
  /** `Watch.name` in the registered monitor; how the service refers to it. */
  watchName: string;
}

export interface StreamWatchLoopOptions {
  entries: StreamWatchEntry[];
  stream: WatchStream;
  /**
   * Where the version to build from comes from.
   *
   * The service and this CLI do not share a version vocabulary — see the note
   * on `_settleAsync` — so the stream says *that* a place moved and this says
   * *what* it moved to.
   */
  source: PlaceVersionSource;
  monitorId: string;
  /** Bearer token; the same one registration used. */
  credential: string;
  /** Rebuild and redeploy. Errors are reported and the stream stays up. */
  redeployAsync: (entry: StreamWatchEntry, version: number) => Promise<void>;
  /** Lets a caller stop the loop; SIGINT is wired to one by default. */
  signal?: AbortSignal;
}

export interface StreamWatchLoopResult {
  redeploys: number;
  failures: number;
  reconnects: number;
  /** True when the monitor went away rather than the user stopping. */
  monitorGone: boolean;
  /** True when the service refused the handshake for good. */
  rejected: boolean;
  /**
   * True when the service cannot observe any of these places, so holding the
   * stream would wait forever. The caller should fall back to polling.
   */
  unobservable: boolean;
}

/**
 * Watch by being told, and rebuild here.
 *
 * The service polls the base place and pushes a `notify` when it moves, so this
 * side holds a socket instead of a poll timer — no Open Cloud quota spent per
 * developer, and the rebuild starts when the change happens rather than up to
 * an interval later.
 *
 * There is no session length. A held connection renews the monitor's lease, so
 * the lease passed to `--watch` is a floor for how long the monitor outlives a
 * dropped link, not a clock on the terminal: this runs until Ctrl-C.
 */
export async function runStreamWatchLoopAsync(
  options: StreamWatchLoopOptions
): Promise<StreamWatchLoopResult> {
  const { entries, stream, source, redeployAsync } = options;

  // Always our own controller, chained to the caller's when there is one: this
  // loop has to be able to stop the stream itself (an unobservable monitor),
  // which it could not do if the only signal belonged to someone else.
  const controller = new AbortController();
  const signal = controller.signal;
  const onSigint = () => controller.abort();
  if (options.signal) {
    if (options.signal.aborted) {
      controller.abort();
    } else {
      options.signal.addEventListener('abort', onSigint, { once: true });
    }
  } else {
    process.on('SIGINT', onSigint);
  }

  const byWatchName = new Map(entries.map((e) => [e.watchName, e]));

  /**
   * What each place has actually been built from here, as an Open Cloud place
   * version. Seeded from the lock and advanced only by a rebuild that
   * succeeded: the service moves its own baseline whether or not anyone was
   * listening, so this map is the only durable record of what exists.
   */
  const built = new Map<string, number | undefined>(
    entries.map((e) => [e.watchName, e.baseline])
  );

  /**
   * The last service-side token each watch was settled at. Purely an
   * optimization — a reconnect that reports the same token needs no Open Cloud
   * call — and deliberately not advanced when a rebuild fails, so the next
   * `ready` retries it.
   */
  const settledAt = new Map<string, string>();

  let redeploys = 0;
  let failures = 0;
  let lastDropReason: string | undefined;
  let unobservable = false;

  /**
   * Watches the service has told us it cannot read, from either direction:
   * the `ready` snapshot on connect, or a `poll-failed` event as it happens.
   *
   * Both are needed. A connection opened before the service's first failed
   * poll gets a clean snapshot, and the next one is an hour away — so without
   * the live tail a private base place would look fine for an hour before the
   * watch admitted it was doing nothing.
   */
  const unreadable = new Set<string>();

  /**
   * Give up the stream once nothing on it can ever fire, so the caller can
   * poll instead — this machine's credentials reach places the service's
   * credential-free driver cannot.
   */
  const abandonIfNothingLeftToWatch = (): boolean => {
    if (unreadable.size < byWatchName.size) {
      return false;
    }
    unobservable = true;
    controller.abort();
    return true;
  };

  OutputHelper.info(
    `Watching ${entries.length} base place${
      entries.length === 1 ? '' : 's'
    } over the watch service. Ctrl-C to stop.`
  );
  for (const entry of entries) {
    OutputHelper.info(
      `  ${entry.label} — base place ${entry.placeId} (${entry.versionType}${
        entry.baseline == null ? '' : ` v${entry.baseline}`
      })`
    );
  }

  /**
   * Bring one watch up to date, given the service's opaque change token.
   *
   * The token is all the service can offer: for a Roblox place it is the
   * asset-delivery content hash, which answers "has this moved" and nothing
   * else. The lock file speaks Open Cloud place versions instead, and the two
   * are not comparable — so a change is confirmed here by asking Open Cloud
   * what the place is actually at, which is the same number the build records.
   */
  const settleAsync = async (
    entry: StreamWatchEntry,
    token: string | null
  ): Promise<void> => {
    if (token != null && settledAt.get(entry.watchName) === token) {
      return;
    }

    let latest: number;
    try {
      latest = await source.resolveLatestPlaceVersionAsync(
        entry.universeId,
        entry.placeId,
        entry.versionType
      );
    } catch (err) {
      // Never fatal. A watch is meant to be left running for hours, and the
      // next frame will ask again.
      OutputHelper.warn(
        `Could not check ${entry.label}: ` +
          (err instanceof Error ? err.message : String(err))
      );
      return;
    }

    const previous = built.get(entry.watchName);
    const settle = () => {
      if (token != null) {
        settledAt.set(entry.watchName, token);
      }
    };

    if (previous === undefined) {
      // Never built here and nothing locked: adopt what is there rather than
      // reading "unknown -> something" as a change.
      built.set(entry.watchName, latest);
      settle();
      return;
    }
    if (latest === previous) {
      settle();
      return;
    }

    OutputHelper.info(
      `${entry.label}: base place moved v${previous} → v${latest}, rebuilding...`
    );
    try {
      await redeployAsync(entry, latest);
      redeploys++;
      built.set(entry.watchName, latest);
      settle();
      OutputHelper.info(`${entry.label}: rebuilt from v${latest}.`);
    } catch (err) {
      // Left unsettled on purpose: the next `ready` sees it as still stale and
      // tries again, which is what a rebuild that failed halfway deserves.
      failures++;
      OutputHelper.error(
        `${entry.label}: rebuild failed — ` +
          (err instanceof Error ? err.message : String(err))
      );
    }
  };

  try {
    const result = await stream.runAsync({
      monitorId: options.monitorId,
      credential: options.credential,
      signal,
      handlers: {
        // Every connection starts here, including reconnects. Nothing is
        // replayed while a client is away, so this is the whole catch-up.
        onReadyAsync: async (ready: WatchStreamReady) => {
          const ours = ready.watches.filter((s) => byWatchName.has(s.name));

          // A source the service cannot read never fires, and the socket says
          // nothing about it — the failure is visible only here. Waiting
          // silently forever is the worst of the options, so a monitor that can
          // see none of these places gives up the stream and lets the caller
          // poll instead, using this machine's credentials, which can reach
          // places the service cannot.
          //
          // Keyed on `sourceError`, not on `state`. `state` tracks dispatching,
          // and a notify that reaches nobody is a success — so a watch whose
          // place is private sits at "pending" forever and never reaches
          // "failed". `sourceError` is the service's answer to exactly this.
          const failedToRead = ours.filter((s) => _isUnreadable(s));

          // An empty intersection is the same silent wait by another route: the
          // monitor exists but holds none of our watches, so nothing can ever
          // arrive for us. Reachable when another checkout re-registered this
          // monitor name with different place names.
          if (ours.length === 0) {
            OutputHelper.warn(
              'The watch monitor holds none of the places this run is ' +
                'watching — another checkout has probably re-registered it.'
            );
            unobservable = true;
            controller.abort();
            return;
          }

          for (const status of failedToRead) {
            if (unreadable.has(status.name)) {
              continue;
            }
            unreadable.add(status.name);
            OutputHelper.warn(
              `The watch service cannot read ${
                byWatchName.get(status.name)!.label
              }` + (status.sourceError ? `: ${status.sourceError}` : '.')
            );
          }
          if (abandonIfNothingLeftToWatch()) {
            return;
          }

          for (const status of ours) {
            if (!unreadable.has(status.name)) {
              await settleAsync(
                byWatchName.get(status.name)!,
                status.currentVersion
              );
            }
          }
        },

        onNotifyAsync: async (notify: WatchStreamNotify) => {
          const entry = byWatchName.get(notify.watchName);
          if (!entry) {
            OutputHelper.verbose(
              `Ignoring a notification for "${notify.watchName}", which this ` +
                'run does not watch.'
            );
            return;
          }
          await settleAsync(entry, notify.version);
        },

        onEvent: (message) => {
          OutputHelper.verbose(
            `  [${message.event.type}] ${message.event.message}`
          );

          // The service only logs this once it has failed several polls in a
          // row, so it already means "not a blip". There is no matching
          // recovered event, so this is one-way — but the cost of being wrong
          // is polling something that could have been streamed, which still
          // works.
          const name = message.event.watchName;
          if (
            message.event.type !== 'poll-failed' ||
            name == null ||
            !byWatchName.has(name) ||
            unreadable.has(name)
          ) {
            return;
          }
          unreadable.add(name);
          OutputHelper.warn(
            `The watch service cannot read ${byWatchName.get(name)!.label}: ${
              message.event.message
            }`
          );
          abandonIfNothingLeftToWatch();
        },

        // The stream swallows a handler's throw so it cannot strand the watch
        // or kill the process; unreported it would be invisible. Everything
        // above already catches its own failures, so reaching here is a bug.
        onHandlerError: (err) => {
          OutputHelper.error(`Watch handler failed: ${err.message}`);
        },

        // A misconfiguration retries on a fixed reason forever, so the same
        // sentence would be printed until someone gave up reading it. Said once
        // per distinct cause, counted after that.
        onReconnect: (attempt, reason) => {
          if (reason === lastDropReason) {
            OutputHelper.verbose(
              `Watch stream still unavailable (attempt ${attempt}).`
            );
            return;
          }
          lastDropReason = reason;
          OutputHelper.warn(`Watch stream dropped: ${reason}`);
        },
      },
    });

    if (result.ending === 'monitor-gone') {
      OutputHelper.warn(
        'The watch monitor was released or its lease lapsed, so nothing is ' +
          'being watched any more. Re-run with --watch to register again.'
      );
    }
    if (result.ending === 'rejected') {
      OutputHelper.error(
        `Could not hold the watch stream: ${
          result.reason ?? 'the service refused the handshake'
        }`
      );
    }
    if (!unobservable) {
      OutputHelper.info(
        `Stopped watching. ${redeploys} rebuild${redeploys === 1 ? '' : 's'}.`
      );
    }

    return {
      redeploys,
      failures,
      reconnects: result.reconnects,
      monitorGone: result.ending === 'monitor-gone',
      rejected: result.ending === 'rejected',
      unobservable,
    };
  } finally {
    if (options.signal) {
      options.signal.removeEventListener('abort', onSigint);
    } else {
      process.off('SIGINT', onSigint);
    }
  }
}
