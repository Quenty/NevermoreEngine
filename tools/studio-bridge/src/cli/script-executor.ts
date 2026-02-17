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
  type StudioBridgePhase,
} from '../server/studio-bridge-server.js';

export interface ExecuteScriptOptions {
  scriptContent: string;
  packageName: string;
  placePath?: string;
  timeoutMs: number;
  verbose: boolean;
  showLogs: boolean;
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
): Promise<void> {
  const { scriptContent, packageName, placePath, timeoutMs, verbose, showLogs } =
    options;

  const useSpinner = !!process.stdout.isTTY && !verbose;

  const reporter = new CompositeReporter(
    [packageName],
    (state: LiveStateTracker) => [
      useSpinner
        ? new SpinnerReporter(state, {
            showLogs,
            actionVerb: 'Running',
          })
        : new SimpleReporter(state, {
            alwaysShowLogs: showLogs,
            successMessage: 'Script completed successfully.',
            failureMessage: 'Script failed.',
          }),
    ]
  );

  await reporter.startAsync();
  reporter.onPackageStart(packageName);

  const startTime = performance.now();

  // Suppress verbose output during spinner rendering
  if (useSpinner) {
    OutputHelper.setVerbose(false);
  }

  const server = new StudioBridgeServer({
    placePath,
    timeoutMs,
    onPhase: (phase: StudioBridgePhase) => {
      if (phase === 'done') return;
      reporter.onPackagePhaseChange(packageName, phase);
    },
  });

  const outputLines: string[] = [];
  let result;
  try {
    await server.startAsync();
    result = await server.executeAsync({
      scriptContent,
      onOutput: (level, body) => {
        // Filter internal plugin messages that leak through LogService
        if (body.startsWith('[StudioBridge]')) {
          return;
        }

        // Collect output for the result logs
        outputLines.push(body);

        // In verbose/simple mode, print output in real-time
        if (!useSpinner) {
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
      },
    });
  } catch (error) {
    const errorMessage =
      error instanceof Error ? error.message : String(error);
    result = {
      success: false,
      logs: `[StudioBridge] Error: ${errorMessage}`,
    };
  } finally {
    await server.stopAsync();
  }

  const elapsed = performance.now() - startTime;

  reporter.onPackageResult({
    packageName,
    success: result.success,
    logs: outputLines.length > 0 ? outputLines.join('\n') : result.logs,
    durationMs: elapsed,
  });

  await reporter.stopAsync();

  process.exit(result.success ? 0 : 1);
}
