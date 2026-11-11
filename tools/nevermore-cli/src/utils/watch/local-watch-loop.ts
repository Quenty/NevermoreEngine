import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type BasePlaceVersionKeyword,
  type PlaceVersionSource,
} from '@quenty/nevermore-deploy';

/** How often to ask Open Cloud whether a base place moved. */
const DEFAULT_POLL_INTERVAL_MS = 15_000;

/** One base place being watched, and what to rebuild when it moves. */
export interface LocalWatchEntry {
  /** Human label for output, e.g. `integration.places.hub`. */
  label: string;
  universeId: number;
  placeId: number;
  versionType: BasePlaceVersionKeyword;
  /**
   * Version this entry was last built from. Undefined means "adopt whatever
   * the first poll sees", which avoids a rebuild on startup for a place that
   * has never been locked.
   */
  baseline?: number;
}

export interface LocalWatchLoopOptions {
  entries: LocalWatchEntry[];
  source: PlaceVersionSource;
  /** Stop watching after this long. */
  durationMs: number;
  pollIntervalMs?: number;
  /** Rebuild and redeploy. Errors are reported and the loop continues. */
  redeployAsync: (entry: LocalWatchEntry, version: number) => Promise<void>;
  /** Lets a caller stop the loop; SIGINT is wired to one by default. */
  signal?: AbortSignal;
  /** Injected in tests. */
  now?: () => number;
  sleepAsync?: (ms: number, signal: AbortSignal) => Promise<void>;
}

export interface LocalWatchLoopResult {
  /** Rebuilds that completed. */
  redeploys: number;
  /** Rebuilds that were attempted and threw. */
  failures: number;
  /** True when the duration ran out rather than the user interrupting. */
  expired: boolean;
}

/**
 * Poll base places and redeploy in-process when one moves.
 *
 * This is what `--watch` does outside CI. Registering with the watch service
 * would be pointless on a laptop: the service's only action is dispatching a
 * GitHub workflow, which would rebuild on a runner rather than here — so a
 * local run keeps the loop in the terminal, where the developer can see it.
 *
 * Poll failures never end the loop. A watch is meant to be left running for
 * hours, and a dropped connection is not a reason to stop watching.
 */
export async function runLocalWatchLoopAsync(
  options: LocalWatchLoopOptions
): Promise<LocalWatchLoopResult> {
  const {
    entries,
    source,
    durationMs,
    redeployAsync,
    pollIntervalMs = DEFAULT_POLL_INTERVAL_MS,
    now = () => Date.now(),
    sleepAsync = _sleepAsync,
  } = options;

  const controller = new AbortController();
  const signal = options.signal ?? controller.signal;
  const onSigint = () => controller.abort();
  if (!options.signal) {
    process.on('SIGINT', onSigint);
  }

  const seen = new Map<string, number | undefined>(
    entries.map((e) => [_key(e), e.baseline])
  );
  const deadline = now() + durationMs;
  let redeploys = 0;
  let failures = 0;

  OutputHelper.info(
    `Watching ${entries.length} base place${
      entries.length === 1 ? '' : 's'
    } locally. Ctrl-C to stop.`
  );
  for (const entry of entries) {
    OutputHelper.info(
      `  ${entry.label} — base place ${entry.placeId} (${entry.versionType}${
        entry.baseline == null ? '' : ` v${entry.baseline}`
      })`
    );
  }

  try {
    while (!signal.aborted && now() < deadline) {
      for (const entry of entries) {
        if (signal.aborted) {
          break;
        }

        let latest: number;
        try {
          latest = await source.resolveLatestPlaceVersionAsync(
            entry.universeId,
            entry.placeId,
            entry.versionType
          );
        } catch (err) {
          OutputHelper.warn(
            `Could not check ${entry.label}: ` +
              (err instanceof Error ? err.message : String(err))
          );
          continue;
        }

        const key = _key(entry);
        const previous = seen.get(key);
        if (previous === undefined) {
          // First sighting of a place with no recorded baseline: adopt it
          // rather than treating "unknown -> something" as a change.
          seen.set(key, latest);
          continue;
        }
        if (latest === previous) {
          continue;
        }

        OutputHelper.info(
          `${entry.label}: base place moved v${previous} → v${latest}, rebuilding...`
        );
        try {
          await redeployAsync(entry, latest);
          redeploys++;
          // Recorded only on success, so a failed rebuild is retried on the
          // next poll instead of being silently skipped forever.
          seen.set(key, latest);
          OutputHelper.info(`${entry.label}: rebuilt from v${latest}.`);
        } catch (err) {
          failures++;
          OutputHelper.error(
            `${entry.label}: rebuild failed — ` +
              (err instanceof Error ? err.message : String(err))
          );
        }
      }

      if (signal.aborted || now() >= deadline) {
        break;
      }
      await sleepAsync(pollIntervalMs, signal);
    }
  } finally {
    if (!options.signal) {
      process.off('SIGINT', onSigint);
    }
  }

  const expired = !signal.aborted;
  OutputHelper.info(
    expired
      ? `Watch lease elapsed. ${redeploys} rebuild${
          redeploys === 1 ? '' : 's'
        }.`
      : `Stopped watching. ${redeploys} rebuild${redeploys === 1 ? '' : 's'}.`
  );

  return { redeploys, failures, expired };
}

function _key(entry: LocalWatchEntry): string {
  return `${entry.placeId}:${entry.versionType}`;
}

function _sleepAsync(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve) => {
    const timer = setTimeout(finish, ms);
    function finish() {
      clearTimeout(timer);
      signal.removeEventListener('abort', finish);
      resolve();
    }
    signal.addEventListener('abort', finish, { once: true });
  });
}
