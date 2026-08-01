import {
  isBasePlaceVersionKeyword,
  type BasePlaceVersionKeyword,
  type DeployTarget,
} from './deploy-config.js';
import { formatTargetSelector } from './target-selector.js';

const DURATION_UNITS_MS: Record<string, number> = {
  s: 1000,
  m: 60 * 1000,
  h: 60 * 60 * 1000,
  d: 24 * 60 * 60 * 1000,
  w: 7 * 24 * 60 * 60 * 1000,
};

/**
 * Lease spelling the service accepts in the register path: digits plus a unit,
 * either case. Mirrors the API's own pattern — a bare number is rejected there
 * as ambiguous, so it is rejected here too rather than sent to be refused.
 */
const LEASE_PATTERN = /^[0-9]+[smhdwSMHDW]$/;

/** Characters the service allows in a monitor or watch name. */
const NAME_PATTERN = /^[A-Za-z0-9._/-]+$/;

/** Service cap on both `MonitorRequest.name` and `Watch.name`. */
const MAX_NAME_LENGTH = 100;

/**
 * Name of the `workflow_dispatch` input the dispatched workflow reads the
 * target selector from. Fixed rather than configurable: both halves of the
 * handshake are Nevermore's, and a mismatch surfaces as a workflow that
 * silently deploys the wrong target.
 */
export const WATCH_INPUT_NAME = 'target';

/** `7d`, `12h`, `30m`, `90s`, `2w`. Returns milliseconds. */
export function parseWatchDuration(text: string): number {
  const match = /^(\d+)([smhdw])$/i.exec(text);
  if (!match) {
    throw new Error(
      `Invalid watch duration "${text}" — expected a number followed by ` +
        `${Object.keys(DURATION_UNITS_MS).join('/')}, e.g. "7d".`
    );
  }
  const amount = Number(match[1]);
  if (amount <= 0) {
    throw new Error(`Watch duration must be greater than zero, got "${text}"`);
  }
  return amount * DURATION_UNITS_MS[match[2]!.toLowerCase()]!;
}

/**
 * A resolved `--watch` value: the endpoint to register with, and the lease it
 * asks for.
 */
export interface WatchOption {
  registerUrl: string;
  /** The lease as the service spells it (`7d`), taken from the register path. */
  lease: string;
  /** The same lease in milliseconds, for reporting. */
  durationMs: number;
}

/**
 * Parse the `--watch` value, which is the register endpoint in full:
 * `--watch https://<host>/v1/register/7d`.
 *
 * A URL rather than a bare duration, deliberately. Nevermore is published from
 * a public repo and has no business knowing a watch service address, so there
 * is nothing for a duration to compose onto — a shorthand would only work by
 * shipping a default host or by depending on an environment variable being set
 * somewhere out of sight. Naming the endpoint at the call site keeps the whole
 * address in the caller's hands and this package free of it.
 *
 * The lease has to be the last path segment, because that is where the API
 * takes it. A URL without one is rejected here rather than sent to be refused
 * with a 400 after the deploy has already shipped.
 */
export function parseWatchOption(value: string): WatchOption {
  if (!/^https?:\/\//i.test(value)) {
    throw new Error(
      `--watch takes the register endpoint URL, not "${value}". ` +
        'Pass the full endpoint including the lease, e.g. ' +
        '--watch https://<watch-service>/v1/register/7d'
    );
  }

  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error(`Invalid --watch URL "${value}"`);
  }

  const lease = url.pathname.split('/').filter(Boolean).pop();
  if (lease == null || !LEASE_PATTERN.test(lease)) {
    throw new Error(
      `--watch URL "${value}" does not end in a lease. The register ` +
        `endpoint takes it as the last path segment, e.g. ` +
        `".../v1/register/7d".`
    );
  }

  return {
    registerUrl: value,
    lease,
    durationMs: parseWatchDuration(lease),
  };
}

/**
 * Coerce a name into the service's character set.
 *
 * npm scopes are the reason this exists: `@quenty/hub` carries an `@`, which
 * the service rejects, but the rest of the name is meaningful and worth
 * keeping. Anything else outside the set becomes `-`.
 *
 * This is lossy and can map two distinct inputs onto one name, so it is not a
 * uniqueness mechanism — callers that need unique names must ensure that
 * themselves, after sanitizing.
 */
export function sanitizeWatchName(name: string): string {
  const cleaned = name
    .replace(/^@/, '')
    .replace(/[^A-Za-z0-9._/-]/g, '-')
    .replace(/^[/.-]+/, '');
  if (cleaned === '' || !NAME_PATTERN.test(cleaned)) {
    throw new Error(`Cannot derive a watch name from "${name}"`);
  }
  // Keep the tail: the distinguishing part of a package/target name is at the
  // end, so truncating the front loses less than truncating the back.
  return cleaned.length > MAX_NAME_LENGTH
    ? cleaned.slice(cleaned.length - MAX_NAME_LENGTH)
    : cleaned;
}

/** One place that will be watched, paired with what to dispatch when it moves. */
export interface WatchPlanEntry {
  /** Selector the dispatched workflow re-deploys, e.g. `integration.places.hub`. */
  selector: string;
  /** Repo-relative workflow path, from the place's `watch` field. */
  workflow: string;
  place: DeployTarget;
}

/**
 * Whether the watch service can poll a `"saved"` base place yet.
 *
 * Its source schema accepts `versionType: "saved"`, but registration refuses it
 * until a credentialed driver exists — a watch that could never fire is not
 * stored. That refusal is per-request, and a request carries every watch in the
 * monitor, so one `"saved"` place would fail the whole registration and take
 * every unrelated watch down with it. Filtering here keeps the blast radius to
 * the place that asked for it.
 *
 * Flip to `true` when the service supports it; nothing else needs to change.
 */
const SAVED_WATCH_SUPPORTED = false;

/** A place that declared no watch, or nothing to watch, and why it was left out. */
export interface WatchPlanSkip {
  selector: string;
  reason:
    | 'no-watch-field'
    | 'no-base-place'
    | 'pinned-base-place'
    | 'saved-not-supported';
}

/** Why a place was left out, in words a user can act on. */
export function describeWatchPlanSkip(skip: WatchPlanSkip): string {
  switch (skip.reason) {
    case 'no-watch-field':
      return `${skip.selector} has no "watch" field`;
    case 'no-base-place':
      return `${skip.selector} has no "basePlace" to watch`;
    case 'pinned-base-place':
      return (
        `${skip.selector} pins its basePlace to an exact version — ` +
        'change it to "published" to make it watchable'
      );
    case 'saved-not-supported':
      return (
        `${skip.selector} tracks its basePlace as "saved", which the watch ` +
        'service cannot poll yet — it watches published versions only. Track ' +
        '"published" to make it watchable.'
      );
  }
}

export interface WatchPlan {
  entries: WatchPlanEntry[];
  skipped: WatchPlanSkip[];
}

/**
 * Decide which of a target's places get watched.
 *
 * A place needs both halves: `watch` says what to dispatch, `basePlace` says
 * what to watch for. Missing either is normal — most places in a config are
 * neither — so they are reported as skips rather than errors, and only become
 * a hard failure if that leaves nothing to register at all.
 */
export function buildWatchPlan(
  targetName: string,
  places: DeployTarget[]
): WatchPlan {
  const entries: WatchPlanEntry[] = [];
  const skipped: WatchPlanSkip[] = [];

  for (const place of places) {
    const selector = formatTargetSelector({
      targetName,
      placeName: place.name,
    });
    if (place.watch == null) {
      skipped.push({ selector, reason: 'no-watch-field' });
      continue;
    }
    if (place.basePlace == null) {
      skipped.push({ selector, reason: 'no-base-place' });
      continue;
    }
    // An exact version pin means "hold this base place still", which is the
    // opposite of watching it: every rebuild would download the same version no
    // matter how many times the watch fired.
    if (
      place.basePlace.version != null &&
      !isBasePlaceVersionKeyword(place.basePlace.version)
    ) {
      skipped.push({ selector, reason: 'pinned-base-place' });
      continue;
    }
    if (!SAVED_WATCH_SUPPORTED && place.basePlace.version === 'saved') {
      skipped.push({ selector, reason: 'saved-not-supported' });
      continue;
    }
    entries.push({ selector, workflow: place.watch, place });
  }

  return { entries, skipped };
}

/**
 * The base place a watch observes.
 *
 * `versionType` mirrors `basePlace.version` and is part of the source's
 * identity on the service: the same place watched for publishes and for saves
 * are two sources, polled separately. Sent explicitly rather than leaning on
 * the schema default, so what the config asked for is what gets stored even if
 * that default moves.
 */
export interface WatchSource {
  type: 'roblox-place';
  universeId: number;
  placeId: number;
  versionType: BasePlaceVersionKeyword;
}

/** Dispatch a GitHub workflow when the source moves. */
export interface WatchWorkflowDispatchAction {
  type: 'github-workflow-dispatch';
  /** Workflow path or file name; only the file name reaches GitHub. */
  workflow: string;
  /** Ref to run at. Omitted means the repository's default branch. */
  ref?: string;
  /** Forwarded verbatim as workflow inputs. */
  inputs?: Record<string, string>;
}

/**
 * Hand the change to whoever is holding the monitor's stream, instead of
 * spending a workflow run to say it.
 *
 * This is what makes a local `--watch` worth registering at all. Dispatching is
 * the wrong shape on a laptop — it rebuilds on a runner rather than in the
 * terminal the developer is watching — so a local run asks to be told and does
 * the rebuild itself.
 *
 * `payload` is opaque to the service and forwarded verbatim, exactly like
 * `inputs`, so the selector vocabulary crosses unchanged.
 */
export interface WatchNotifyAction {
  type: 'notify';
  payload?: Record<string, string>;
}

export type WatchAction = WatchWorkflowDispatchAction | WatchNotifyAction;

export function isWatchNotifyAction(
  action: WatchAction
): action is WatchNotifyAction {
  return action.type === 'notify';
}

/** One "if this moves, run that" pair inside a monitor. */
export interface WatchEntry {
  /** Unique within the monitor; echoed back in status and events. */
  name: string;
  source: WatchSource;
  /**
   * The version this watch was last built against — the resolved value from the
   * lock file. Supplying it means registering never itself triggers a dispatch.
   * Omitted, the first poll adopts whatever it observes, which behaves the same.
   */
  baselineVersion?: string;
  action: WatchAction;
}

/**
 * One monitor: every watch a single CLI invocation is responsible for.
 *
 * The service is idempotent on `(repository, name)` and replaces the whole
 * watch list on re-apply, so a registration has to carry every watch that name
 * owns — not just the ones whose places happened to deploy this run.
 */
export interface WatchRegistrationRequest {
  /** Lease key within the repository. */
  monitorName: string;
  /** `owner/repo`. */
  repository: string;
  /** GitHub token the service dispatches with. */
  githubToken: string;
  /** Open Cloud key the service polls private base places with, if shared. */
  robloxApiKey?: string;
  watches: WatchEntry[];
  /** Minimum gap between dispatches for one watch. */
  cooldownSeconds?: number;
}

export interface WatchRegistrationResult {
  monitorId?: string;
  /** Content hash of the stored config; credentials and lease excluded. */
  revision?: string;
  leaseExpiresAt?: string;
  /** False when the applied config was identical to what was already stored. */
  changed?: boolean;
  /** How many watches the service reports the monitor holding. */
  watchCount?: number;
}

/** What one watch's forced dispatch did. */
export interface WatchTriggerOutcome {
  watchName?: string;
  ok?: boolean;
  detail?: string;
}

export interface WatchTriggerResult {
  results: WatchTriggerOutcome[];
}

/**
 * The one thing watch registration needs from the outside world.
 *
 * Declared as a port for the same reason as `PlaceVersionSource`: this package
 * stays free of network and auth, so the rules about what gets watched can't
 * drift between callers. The HTTP implementation lives in the CLI.
 */
export interface WatchRegistry {
  registerAsync(
    request: WatchRegistrationRequest
  ): Promise<WatchRegistrationResult>;

  /**
   * Fire a monitor's actions immediately, ignoring drift and cooldown.
   *
   * This is how a dryrun proves the routing works: registering only says the
   * service accepted the config, while a forced dispatch shows the workflow
   * actually receiving the selector.
   */
  triggerAsync(
    monitorId: string,
    credential: string,
    options?: { watchName?: string }
  ): Promise<WatchTriggerResult>;
}
