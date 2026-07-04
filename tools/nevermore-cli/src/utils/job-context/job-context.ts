import { type BuildPlaceOptions, type BuiltPlace } from '../build/build.js';

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

  /** Retrieve raw logs from the most recent script execution on this deployment. */
  getLogsAsync(deployment: Deployment): Promise<string>;

  /** Release a single deployment (stop bridge / clear task metadata). */
  releaseAsync(deployment: Deployment): Promise<void>;

  /** Eagerly release a built place's temporary resources. Idempotent. */
  releaseBuiltPlaceAsync(builtPlace: BuiltPlace): Promise<void>;

  /** Final teardown — release all remaining deployments and built places. Called once at end of batch. */
  disposeAsync(): Promise<void>;
}
