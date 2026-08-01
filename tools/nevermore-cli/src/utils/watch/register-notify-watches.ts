import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  WATCH_INPUT_NAME,
  sanitizeWatchName,
  type WatchEntry,
  type WatchOption,
  type WatchRegistry,
} from '@quenty/nevermore-deploy';
import { HttpWatchRegistry } from './http-watch-registry.js';
import { tryResolveGithubDispatchContext } from './github-context.js';
import { type LocalWatchEntry } from './local-watch-loop.js';
import { type StreamWatchEntry } from './stream-watch-loop.js';

export interface RegisterNotifyWatchesOptions {
  option: WatchOption;
  /** Lease key within the repository, as for a dispatching monitor. */
  monitorName: string;
  entries: LocalWatchEntry[];
  /** Open Cloud key to share, so the service can poll a private base place. */
  robloxApiKey?: string;
  /** Injected in tests; defaults to the HTTP registry. */
  createRegistry?: (registerUrl: string) => WatchRegistry;
}

export type RegisterNotifyWatchesResult =
  | {
      success: true;
      monitorId: string;
      /** Bearer token for the stream; the same one registration used. */
      credential: string;
      entries: StreamWatchEntry[];
    }
  | {
      success: false;
      reason:
        | 'no_github_context'
        | 'no_token'
        | 'unwatchable_version_type'
        | 'no_entries'
        | 'register_failed'
        | 'no_monitor_id';
      detail?: string;
    };

/**
 * Register a monitor that notifies this process instead of dispatching CI.
 *
 * Best-effort on purpose. Every way this can fail — no GitHub identity to
 * register under, no token, a `"saved"` base place the service cannot poll, a
 * service that is unreachable — has a working answer already: poll Open Cloud
 * from here. So a failure downgrades the watch rather than the run, and the
 * caller falls back.
 */
export async function tryRegisterNotifyWatchesAsync(
  options: RegisterNotifyWatchesOptions
): Promise<RegisterNotifyWatchesResult> {
  const { option, entries } = options;

  if (entries.length === 0) {
    return { success: false, reason: 'no_entries' };
  }

  // The service refuses `"saved"` at registration, and one request carries the
  // whole monitor, so a single such place would fail all of them. Rather than
  // watch some places one way and some the other, the whole run falls back to
  // polling — which handles every version type this machine has credentials for.
  const unwatchable = entries.filter((e) => e.versionType !== 'published');
  if (unwatchable.length > 0) {
    return {
      success: false,
      reason: 'unwatchable_version_type',
      detail: unwatchable.map((e) => e.label).join(', '),
    };
  }

  const contextResult = tryResolveGithubDispatchContext();
  if (!contextResult.success) {
    return { success: false, reason: 'no_github_context' };
  }
  const context = contextResult.context;
  // Registration needs a write-scoped PAT even though a notify never spends it:
  // the repository is the only identity this service has, and it is what a
  // monitor's leases and caps are counted against.
  if (!context.token) {
    return { success: false, reason: 'no_token' };
  }

  const streamEntries: StreamWatchEntry[] = entries.map((entry) => ({
    ...entry,
    watchName: sanitizeWatchName(entry.label),
  }));
  _disambiguateWatchNames(streamEntries);

  const watches: WatchEntry[] = streamEntries.map((entry) => ({
    name: entry.watchName,
    source: {
      type: 'roblox-place',
      universeId: entry.universeId,
      placeId: entry.placeId,
      versionType: 'published',
    },
    // No `baselineVersion`, for the same reason as a dispatching watch: the
    // service compares its own token (an asset-delivery content hash) by string
    // equality, and the lock's Open Cloud version number would never match it.
    // The `ready` reconcile covers what a baseline was for — it re-checks every
    // watch against Open Cloud on connect.
    action: {
      type: 'notify',
      // Same key a dispatching watch puts the selector under, so the two modes
      // describe a change the same way even though only one crosses into CI.
      payload: { [WATCH_INPUT_NAME]: entry.label },
    },
  }));

  const registry = (options.createRegistry ?? _defaultRegistry)(
    option.registerUrl
  );

  let result;
  try {
    result = await registry.registerAsync({
      // Distinct from the dispatching monitor's name. They hold different
      // actions, and re-registering replaces a monitor's whole watch list — so
      // sharing a name would mean a local watch silently disarming CI's.
      monitorName: sanitizeWatchName(`${options.monitorName}/local`),
      repository: context.repository,
      githubToken: context.token,
      robloxApiKey: options.robloxApiKey,
      watches,
    });
  } catch (err) {
    return {
      success: false,
      reason: 'register_failed',
      detail: err instanceof Error ? err.message : String(err),
    };
  }

  if (!result.monitorId) {
    return { success: false, reason: 'no_monitor_id' };
  }

  OutputHelper.verbose(
    `Registered a notify monitor (${result.monitorId}), lease ${option.lease}.`
  );

  return {
    success: true,
    monitorId: result.monitorId,
    credential: context.token,
    entries: streamEntries,
  };
}

/** Why the run is polling instead, in words a user can act on. */
export function describeNotifyWatchFallback(
  result: RegisterNotifyWatchesResult & { success: false }
): string {
  switch (result.reason) {
    case 'no_entries':
      return 'nothing to watch';
    case 'unwatchable_version_type':
      return (
        `the watch service polls published versions only, and ` +
        `${result.detail} tracks "saved"`
      );
    case 'no_github_context':
      return 'this checkout has no GitHub repository to register under';
    case 'no_token':
      return 'no GitHub token is set (NEVERMORE_WATCH_TOKEN or GITHUB_TOKEN)';
    case 'no_monitor_id':
      return 'the service registered the monitor but returned no id';
    case 'register_failed':
      return `the watch service refused the registration — ${result.detail}`;
  }
}

function _defaultRegistry(registerUrl: string): WatchRegistry {
  return new HttpWatchRegistry({ registerUrl });
}

/**
 * Make every watch name unique within the monitor.
 *
 * Names come from selectors, which are unique per target — except that an
 * unnamed place in a multi-place target has no name to contribute, so two of
 * them produce the same selector. Appending the place id separates them without
 * failing a deploy that already shipped.
 */
function _disambiguateWatchNames(entries: StreamWatchEntry[]): void {
  const byName = new Map<string, StreamWatchEntry[]>();
  for (const entry of entries) {
    const group = byName.get(entry.watchName);
    if (group) {
      group.push(entry);
    } else {
      byName.set(entry.watchName, [entry]);
    }
  }
  for (const group of byName.values()) {
    if (group.length === 1) {
      continue;
    }
    for (const entry of group) {
      entry.watchName = sanitizeWatchName(
        `${entry.watchName}/${entry.placeId}`
      );
    }
  }
}
