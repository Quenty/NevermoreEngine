import { type BuildPlaceOptions, type BuiltPlace } from '../build/build.js';
import { type StructuredTestResults } from '../testing/structured-test-results.js';
import { type LogFetchStats } from '../testing/log-fetch-stats.js';
import { type TaskLogMessage } from '../open-cloud/open-cloud-client.js';

/** A run's output, with the severity and the fetch that produced it. */
export interface JobLogs {
  text: string;
  /**
   * The same output split into typed messages, when the transport reports
   * severity. Empty for one that does not — a local run reads its logs off the
   * Studio bridge, which says only what was printed.
   */
  messages: TaskLogMessage[];
  /**
   * What collecting them took, when the transport can say. Absent rather than
   * zeroed, so "no fetch to measure" cannot read as "a fetch that found
   * nothing".
   */
  stats?: LogFetchStats;
}

export type { BuiltPlace } from '../build/build.js';

export interface DeployPlaceOptions {
  builtPlace: BuiltPlace;
  packageName: string;
  packagePath: string;
}

export interface RunScriptOptions {
  scriptContent: string;
  packageName: string;
  timeoutMs?: number;
}

export interface ScriptRunResult {
  /** Whether the execution infrastructure succeeded (not test assertions). */
  success: boolean;
  /**
   * Optional inner script execution time, reported when the context can
   * measure it directly (e.g. aggregated batch mode reports per-package
   * pcall durations). When undefined, callers should fall back to their own
   * wall-clock measurement.
   */
  durationMs?: number;
  /** Final task state (e.g. 'COMPLETE', 'FAILED', 'CANCELLED'). */
  taskState?: string;
  /** Error message from the execution backend, if any. */
  errorMessage?: string;
  /**
   * Everything the executed script returned, in order — the structured channel
   * out of a run, as opposed to its printed output. Engine logs are truncated
   * by Open Cloud on long runs, so anything a caller must read back exactly
   * belongs here rather than in the log text.
   *
   * `undefined` means the transport never delivered a return channel: a cloud
   * task that ended without an `output` (a FAILED task carries none, and an
   * oversize return value fails the task rather than truncating the value), a
   * bridge run that timed out or disconnected, or a context that does not
   * carry return values at all. That is deliberately distinct from `[]`, which
   * means the script ran and returned nothing — a caller that needs the value
   * can fall back to parsing logs in the first case but not the second.
   *
   * Values are JSON-shaped, but the two transports spell exotic Luau types
   * differently: Open Cloud auto-serializes them, while the Studio bridge
   * marshals them into `{ type, value }` wrappers (`SerializedReturnValue`).
   * Plain tables of strings, numbers and booleans come back identically on
   * both, so structured results should stay inside that subset.
   */
  returnValues?: unknown[];
  /**
   * The run's structured test results, when the context resolved them itself
   * rather than leaving them in `returnValues` for the caller to decode.
   *
   * Only aggregated batch mode sets this: one execution covers every package, so
   * its return value belongs to no single one of them and the per-package
   * results have to be recovered from the batch summary first. A context that
   * sets this has also reported where the counts came from, so the caller does
   * not report it a second time.
   */
  testResults?: StructuredTestResults;
  /**
   * True when this run's verdict rests on returned results alone, its log
   * output having been dropped before it reached us.
   *
   * A narrower verdict than an ordinary one: the counts are exact, but with no
   * text there is nothing to check for tracebacks and nothing to read when
   * something did go wrong. Reported so it can be shown as such rather than as
   * an ordinary pass.
   */
  logsLost?: boolean;
}

/**
 * Opaque handle representing a single deployed place.
 * Returned by `deployBuiltPlaceAsync`, threaded through `runScriptAsync`/`getLogsAsync`/`releaseAsync`.
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface
export interface Deployment {}

export interface JobContext {
  /** Build a .rbxl place file. Returns an opaque handle — lifecycle managed by the context. */
  buildPlaceAsync(options: BuildPlaceOptions): Promise<BuiltPlace>;

  /** Deploy a built place to the execution environment. Returns a handle for subsequent operations. */
  deployBuiltPlaceAsync(options: DeployPlaceOptions): Promise<Deployment>;

  /** Execute a Luau script in a deployed place. */
  runScriptAsync(
    deployment: Deployment,
    options: RunScriptOptions
  ): Promise<ScriptRunResult>;

  /**
   * Everything the most recent script execution printed.
   *
   * One value rather than a log plus two optional side-channels for its
   * severity and its fetch: they all come from the same fetch, so returning
   * them together removes both the chance of asking a context that does not
   * implement one and the chance of handing an accessor the wrong handle.
   */
  getLogsAsync(deployment: Deployment): Promise<JobLogs>;

  /** Release a single deployment (stop bridge / clear task metadata). */
  releaseAsync(deployment: Deployment): Promise<void>;

  /** Eagerly release a built place's temporary resources. Idempotent. */
  releaseBuiltPlaceAsync(builtPlace: BuiltPlace): Promise<void>;

  /** Final teardown — release all remaining deployments and built places. Called once at end of batch. */
  disposeAsync(): Promise<void>;
}
