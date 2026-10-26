/**
 * Shared script execution lifecycle — reporter + server setup used by
 * both the `run` and `exec` commands.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  CompositeReporter,
  SimpleReporter,
  SpinnerReporter,
  type LiveStateTracker,
} from '@quenty/cli-output-helpers/reporting';
import {
  StudioBridgeServer,
  type StudioBridgeResult,
  type StudioBridgePhase,
} from '../server/studio-bridge-server.js';
import type {
  OutputLevel,
  SerializedReturnValue,
} from '../server/web-socket-protocol.js';
import { isPersistentPluginInstalled } from '../plugin/plugin-discovery.js';
import { runInManagedStudioAsync } from './managed-studio-run.js';

export interface ExecuteScriptOptions {
  scriptContent: string;
  packageName: string;
  placePath?: string;
  timeoutMs: number;
  verbose: boolean;
  showLogs: boolean;
  filePath?: string;
  /** Skip the progress reporter, for when stdout carries JSON. */
  quiet?: boolean;
}

export interface ExecuteScriptResult {
  success: boolean;
  output: string[];
  error?: string;
  returnValues?: SerializedReturnValue[];
  durationMs: number;
}

/**
 * Resolves and validates a place file path. Returns undefined if no place
 * was specified, or the resolved absolute path if it exists.
 */
export async function resolvePlacePathAsync(
  place: string | undefined
): Promise<string | undefined> {
  if (!place) return undefined;

  const resolved = path.resolve(place);
  try {
    await fs.access(resolved);
  } catch {
    OutputHelper.error(`Place file not found: ${resolved}`);
    process.exit(1);
  }
  return resolved;
}

/**
 * Runs a Luau script through the StudioBridgeServer with full reporter
 * lifecycle (spinner or simple output).
 */
export async function executeScriptAsync(
  options: ExecuteScriptOptions
): Promise<ExecuteScriptResult> {
  const { shouldDelegateToDockerAsync, delegateToDockerAsync } = await import(
    '../docker/docker-delegator.js'
  );

  if (await shouldDelegateToDockerAsync()) {
    OutputHelper.verbose(
      '[StudioBridge] No Wine detected, delegating to Docker'
    );
    await delegateToDockerAsync(options);
    throw new Error('delegateToDockerAsync returned without exiting');
  }

  const {
    scriptContent,
    packageName,
    placePath,
    timeoutMs,
    verbose,
    showLogs,
    quiet = false,
  } = options;

  const useSpinner = !quiet && !!process.stdout.isTTY && !verbose;

  const reporter = new CompositeReporter(
    [packageName],
    (state: LiveStateTracker) => [
      useSpinner
        ? new SpinnerReporter(state, {
            showLogs,
            actionVerb: 'Running',
          })
        : new SimpleReporter(state, {
            alwaysShowLogs: false,
            successMessage: 'Script completed successfully.',
            failureMessage: 'Script failed.',
          }),
    ]
  );

  if (!quiet) {
    await reporter.startAsync();
    reporter.onPackageStart(packageName);
  }

  const startTime = performance.now();

  // Suppress verbose output during spinner rendering
  if (useSpinner) {
    OutputHelper.setVerbose(false);
  }

  const outputLines: string[] = [];
  const onOutput = (level: OutputLevel, body: string): void => {
    // Filter internal plugin messages that leak through LogService
    if (body.startsWith('[StudioBridge]')) {
      return;
    }

    // Collect output for the result logs
    outputLines.push(body);

    // In verbose/simple mode, print output in real-time
    if (!useSpinner && !quiet) {
      switch (level) {
        case 'Warning':
          OutputHelper.warn(body);
          break;
        case 'Error':
          OutputHelper.error(body);
          break;
        default:
          console.log(body);
          break;
      }
    }
  };
  const onPhase = (phase: StudioBridgePhase): void => {
    if (phase === 'done' || quiet) return;
    reporter.onPackagePhaseChange(packageName, phase);
  };

  let server: StudioBridgeServer | undefined;
  let result: StudioBridgeResult;
  try {
    if (isPersistentPluginInstalled()) {
      const execResult = await runInManagedStudioAsync({
        scriptContent,
        placePath,
        timeoutMs,
        onPhase,
      });
      for (const entry of execResult.output) {
        onOutput(entry.level, entry.body);
      }
      result = {
        success: execResult.success,
        logs: execResult.error ?? '',
        returnValues: execResult.returnValues,
      };
    } else {
      server = new StudioBridgeServer({ placePath, timeoutMs, onPhase });
      await server.startAsync();
      result = await server.executeAsync({ scriptContent, onOutput });
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    result = {
      success: false,
      logs: `[StudioBridge] Error: ${errorMessage}`,
    };
  } finally {
    await server?.stopAsync();
  }

  const elapsed = performance.now() - startTime;

  if (!quiet) {
    reporter.onPackageResult({
      packageName,
      success: result.success,
      logs: outputLines.length > 0 ? outputLines.join('\n') : result.logs,
      durationMs: elapsed,
    });

    await reporter.stopAsync();
  }

  return {
    success: result.success,
    output: outputLines,
    error: result.success || !result.logs ? undefined : result.logs,
    returnValues: result.returnValues,
    durationMs: elapsed,
  };
}
