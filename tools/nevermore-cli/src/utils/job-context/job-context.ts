import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import { type DeployTarget } from '../build/deploy-config.js';

export interface DeployPlaceOptions {
  rbxlPath: string;
  /** Required by cloud, ignored by local. */
  deployTarget?: DeployTarget;
  reporter: Reporter;
  packageName: string;
  packagePath: string;
}

export interface RunScriptOptions {
  scriptContent: string;
  reporter: Reporter;
  packageName: string;
  timeoutMs?: number;
}

export interface ScriptRunResult {
  /** Whether the execution infrastructure succeeded (not test assertions). */
  success: boolean;
}

export interface JobContext {
  /** Deploy a built place to the execution environment. */
  deployBuiltPlaceAsync(options: DeployPlaceOptions): Promise<void>;

  /** Execute a Luau script in the deployed place. */
  runScriptAsync(options: RunScriptOptions): Promise<ScriptRunResult>;

  /** Retrieve raw logs from the most recent script execution. */
  getLogsAsync(): Promise<string>;

  /** Clean up resources from the current execution cycle. */
  cleanupAsync(): Promise<void>;
}
