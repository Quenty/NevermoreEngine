import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import { type DeployTarget } from '../build/deploy-config.js';

export interface DeployPlaceOptions {
  rbxlPath: string;
  /** Required by cloud, ignored by local. */
  deployTarget?: DeployTarget;
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
}

/**
 * Opaque handle representing a single deployed place.
 * Returned by `deployBuiltPlaceAsync`, threaded through `runScriptAsync`/`getLogsAsync`/`releaseAsync`.
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface
export interface Deployment {}

export interface JobContext {
  /** Deploy a built place to the execution environment. Returns a handle for subsequent operations. */
  deployBuiltPlaceAsync(reporter: Reporter, options: DeployPlaceOptions): Promise<Deployment>;

  /** Execute a Luau script in a deployed place. */
  runScriptAsync(deployment: Deployment, reporter: Reporter, options: RunScriptOptions): Promise<ScriptRunResult>;

  /** Retrieve raw logs from the most recent script execution on this deployment. */
  getLogsAsync(deployment: Deployment): Promise<string>;

  /** Release a single deployment (stop bridge / clear task metadata). */
  releaseAsync(deployment: Deployment): Promise<void>;

  /** Final teardown — release all remaining deployments. Called once at end of batch. */
  disposeAsync(): Promise<void>;
}
