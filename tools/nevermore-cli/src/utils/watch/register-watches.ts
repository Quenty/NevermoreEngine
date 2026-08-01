import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  WATCH_INPUT_NAME,
  buildWatchPlan,
  describeWatchPlanSkip,
  parseTargetSelector,
  sanitizeWatchName,
  type DeployTarget,
  type WatchEntry,
  type WatchOption,
  type WatchRegistrationRequest,
  type WatchRegistry,
  type WatchWorkflowDispatchAction,
} from '@quenty/nevermore-deploy';
import { HttpWatchRegistry } from './http-watch-registry.js';
import {
  describeGithubContextFailure,
  describeMissingWatchToken,
  tryResolveGithubDispatchContext,
} from './github-context.js';

/**
 * A watch this path is registering, narrowed to the action it always builds.
 *
 * `WatchEntry.action` is a union because a monitor can also notify a held
 * stream, but this is the CI-shaped half of `--watch` and only ever dispatches
 * a workflow — narrowing here keeps `ref` and `inputs` reachable without a cast.
 */
type DispatchWatchEntry = WatchEntry & { action: WatchWorkflowDispatchAction };

/** One place `--watch` should consider registering. */
export interface WatchCandidate {
  /**
   * Deploy target the place belongs to. A selector (`integration.places.hub`)
   * is accepted and narrowed to its target, since the dispatch selector is
   * rebuilt from the target and the place — appending to a selector that
   * already names a place would produce `integration.places.hub.places.hub`,
   * which nothing can re-resolve.
   */
  targetName: string;
  /** npm package name, used to keep watch names unique across a batch. */
  packageName: string;
  place: DeployTarget;
}

export interface RegisterWatchesOptions {
  option: WatchOption;
  /**
   * Lease key within the repository. Every watch this invocation is
   * responsible for goes under this one name, and re-registering replaces the
   * whole list — so the candidates must be the complete set, not just what
   * deployed.
   */
  monitorName: string;
  candidates: WatchCandidate[];
  /** Open Cloud key to share, so the service can poll private base places. */
  robloxApiKey?: string;
  /**
   * Force a dispatch immediately after registering, ignoring drift.
   *
   * Registering only proves the service accepted the config. Firing proves the
   * workflow actually receives the selector, which is the half that has
   * historically broken — so a dryrun asks for it.
   */
  triggerAfterRegister?: boolean;
  /** Injected in tests; defaults to the HTTP registry. */
  createRegistry?: (registerUrl: string) => WatchRegistry;
}

export interface RegisterWatchesResult {
  /** Watches in the registered monitor. Zero means nothing was sent. */
  registered: number;
  /** True when the service reported the config differing from what it held. */
  changed?: boolean;
  /** Watches that dispatched, when a trigger was requested. */
  triggered?: number;
}

/**
 * Register every watch this invocation owns, in one call.
 *
 * One call is not just an efficiency: the service replaces a monitor's entire
 * watch list on re-apply, so splitting a run across several registrations under
 * one name would leave only the last one standing. The caller decides what the
 * complete set is; this turns it into a request.
 *
 * Runs after the deploy so the monitor only exists once the build it is meant
 * to keep fresh has actually shipped.
 */
export async function registerWatchesAsync(
  options: RegisterWatchesOptions
): Promise<RegisterWatchesResult> {
  const { option, candidates } = options;

  const watches: DispatchWatchEntry[] = [];
  const skipped: string[] = [];

  // A place that declared `watch` and then got left out is worth saying out
  // loud — the user asked for it. A place that never declared one is just
  // ordinary config, and there are usually many, so that stays verbose-only.
  const unmet: string[] = [];

  for (const candidate of candidates) {
    const { targetName } = parseTargetSelector(candidate.targetName);
    const plan = buildWatchPlan(targetName, [candidate.place]);
    for (const skip of plan.skipped) {
      const described = describeWatchPlanSkip(skip);
      skipped.push(described);
      if (skip.reason !== 'no-watch-field') {
        unmet.push(described);
      }
    }
    for (const entry of plan.entries) {
      watches.push(_buildWatchEntry(candidate, targetName, entry));
    }
  }

  _disambiguateWatchNames(watches);

  if (skipped.length > 0) {
    OutputHelper.verbose(`Not watching ${skipped.length} place(s):`);
    for (const line of skipped) {
      OutputHelper.verbose(`  ${line}`);
    }
  }

  if (watches.length === 0) {
    OutputHelper.warn(
      [
        '--watch was requested, but no place is watchable.',
        ...skipped.map((line) => `  ${line}`),
        'Add a "watch" path and a "published" basePlace to the place you want ' +
          'hot-reloaded.',
      ].join('\n')
    );
    return { registered: 0 };
  }

  if (unmet.length > 0) {
    OutputHelper.warn(
      [
        `${unmet.length} place(s) asked to be watched but could not be:`,
        ...unmet.map((line) => `  ${line}`),
      ].join('\n')
    );
  }

  const contextResult = tryResolveGithubDispatchContext();
  if (!contextResult.success) {
    throw new Error(describeGithubContextFailure(contextResult.reason));
  }
  const context = contextResult.context;
  if (!context.token) {
    throw new Error(describeMissingWatchToken());
  }

  // The ref is baked into each action rather than left to the service's
  // default-branch fallback: a watch registered from a branch should rebuild
  // that branch, not whatever main happens to hold.
  for (const watch of watches) {
    watch.action.ref = context.ref;
  }

  const request: WatchRegistrationRequest = {
    // The ref is part of the monitor's identity because it is part of what the
    // monitor does: every action dispatches at `context.ref`. Without it, a
    // `batch deploy --watch` from any branch would re-point the production
    // monitor's whole watch list at that branch, and the next base place edit
    // would rebuild the wrong ref — or a deleted one.
    monitorName: sanitizeWatchName(`${options.monitorName}/${context.ref}`),
    repository: context.repository,
    githubToken: context.token,
    robloxApiKey: options.robloxApiKey,
    watches,
  };

  const registry = (options.createRegistry ?? _defaultRegistry)(
    option.registerUrl
  );
  const result = await registry.registerAsync(request);

  const label = result.changed === false ? 'Renewed' : 'Registered';
  OutputHelper.info(
    `${label} watch monitor "${request.monitorName}" — ${watches.length} ` +
      `watch${watches.length === 1 ? '' : 'es'}, lease ${option.lease}` +
      (result.leaseExpiresAt ? ` (expires ${result.leaseExpiresAt})` : '')
  );
  for (const watch of watches) {
    OutputHelper.verbose(
      `  ${watch.name}: base place ${watch.source.placeId} → ` +
        `${watch.action.inputs?.[WATCH_INPUT_NAME] ?? watch.action.workflow}`
    );
  }

  let triggered: number | undefined;
  if (options.triggerAfterRegister) {
    triggered = await _triggerAsync(registry, result, context.token);
  }

  return { registered: watches.length, changed: result.changed, triggered };
}

/**
 * Force a dispatch and report what each watch did.
 *
 * Reported rather than thrown: the registration succeeded, and a monitor that
 * exists is worth keeping even if the demonstration dispatch failed. The
 * per-watch `ok` is what actually proves routing, so a failure there is
 * surfaced loudly.
 */
async function _triggerAsync(
  registry: WatchRegistry,
  result: { monitorId?: string },
  token: string
): Promise<number | undefined> {
  if (!result.monitorId) {
    OutputHelper.warn(
      'Registered, but the service returned no monitorId — cannot force a ' +
        'dispatch to prove routing.'
    );
    return undefined;
  }

  let outcome;
  try {
    outcome = await registry.triggerAsync(result.monitorId, token);
  } catch (err) {
    OutputHelper.error(
      `Registered, but forcing a dispatch failed: ` +
        (err instanceof Error ? err.message : String(err))
    );
    return undefined;
  }

  const ok = outcome.results.filter((r) => r.ok !== false);
  const failed = outcome.results.filter((r) => r.ok === false);

  OutputHelper.info(
    `Forced a dispatch: ${ok.length} of ${outcome.results.length} watch` +
      `${outcome.results.length === 1 ? '' : 'es'} fired.`
  );
  for (const r of outcome.results) {
    const line = `  ${r.watchName ?? '(unnamed)'}: ${
      r.ok === false ? 'FAILED' : 'dispatched'
    }${r.detail ? ` — ${r.detail}` : ''}`;
    if (r.ok === false) {
      OutputHelper.warn(line);
    } else {
      OutputHelper.info(line);
    }
  }
  if (failed.length > 0) {
    OutputHelper.warn(
      'A watch registered but could not dispatch. The routing is not working ' +
        'end to end yet — check the workflow path and the ref.'
    );
  }

  return ok.length;
}

function _defaultRegistry(registerUrl: string): WatchRegistry {
  return new HttpWatchRegistry({ registerUrl });
}

/**
 * Make every watch name unique within the monitor.
 *
 * `Watch.name` is documented as unique per monitor but the schema does not
 * enforce it, so a collision is resolved server-side — silently dropping a
 * watch rather than failing. Places are only *optionally* named, so a
 * multi-place target with unnamed places collides by construction. Appending
 * the base place id disambiguates without failing a deploy that already
 * shipped, and only touches the names that actually clash.
 */
function _disambiguateWatchNames(watches: WatchEntry[]): void {
  const byName = new Map<string, WatchEntry[]>();
  for (const watch of watches) {
    const group = byName.get(watch.name);
    if (group) {
      group.push(watch);
    } else {
      byName.set(watch.name, [watch]);
    }
  }

  for (const group of byName.values()) {
    if (group.length === 1) {
      continue;
    }
    for (const watch of group) {
      watch.name = sanitizeWatchName(`${watch.name}/${watch.source.placeId}`);
    }
  }
}

function _buildWatchEntry(
  candidate: WatchCandidate,
  targetName: string,
  entry: { selector: string; workflow: string }
): DispatchWatchEntry {
  const basePlace = candidate.place.basePlace!;

  return {
    name: sanitizeWatchName(
      `${candidate.packageName}/${candidate.place.name ?? targetName}`
    ),
    source: {
      type: 'roblox-place',
      universeId: basePlace.universeId,
      placeId: basePlace.placeId,
      // An omitted pin resolves as "published", the same default the resolver
      // builds with, so the watch observes exactly what the build used.
      versionType: basePlace.version === 'saved' ? 'saved' : 'published',
    },
    // Deliberately no `baselineVersion`.
    //
    // The service's version token for a Roblox place is the asset-delivery
    // content hash, and it compares tokens by string equality. Our lock file
    // holds the Open Cloud place version — a number, in a different vocabulary
    // — so handing it over would never match, and the first poll would read it
    // as drift and dispatch a rebuild of something already current.
    //
    // Omitting it means the first poll adopts what it observes, which is what
    // supplying a baseline was meant to achieve. The only thing given up is a
    // change landing in the seconds between the deploy and this call.
    action: {
      type: 'github-workflow-dispatch',
      workflow: entry.workflow,
      inputs: { [WATCH_INPUT_NAME]: entry.selector },
    },
  };
}
