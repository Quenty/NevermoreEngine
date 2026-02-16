import * as fs from 'fs/promises';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { OpenCloudClient } from '../../open-cloud/open-cloud-client.js';
import { tryRenamePlaceAsync } from '../../auth/roblox-auth/index.js';
import {
  buildPlaceNameAsync,
  timeoutAsync,
} from '../../nevermore-cli-utils.js';
import { buildPlaceAsync } from '../../build/build.js';
import { uploadPlaceAsync } from '../../build/upload.js';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import { parseTestLogs } from '../test-log-parser.js';
import { StudioBridge } from '@quenty/studio-bridge';

export type TestPhase = 'building' | 'uploading' | 'scheduling' | 'executing';

export interface SingleTestResult {
  success: boolean;
  logs: string;
}

export interface SingleTestOptions {
  packagePath: string;
  reporter: Reporter;
  packageName: string;
  timeoutMs?: number;
  /** Luau code to execute directly, bypassing the configured scriptTemplate. */
  scriptText?: string;
}

export interface CloudTestOptions extends SingleTestOptions {
  client: OpenCloudClient;
}

/**
 * Build, upload, and run a test for a single package.
 * Returns a structured result — no process.exit, no console output beyond
 * what buildPlaceAsync/uploadPlaceAsync and OpenCloudClient emit.
 */
export async function runSingleCloudTestAsync(
  options: CloudTestOptions
): Promise<SingleTestResult> {
  const {
    packagePath,
    client,
    reporter,
    packageName,
    timeoutMs = 120_000,
    scriptText,
  } = options;

  const buildResult = await buildPlaceAsync({
    targetName: 'test',
    outputFileName: 'test.rbxl',
    packagePath,
    reporter,
    packageName,
  });

  const { target, version } = await uploadPlaceAsync({
    buildResult,
    args: {},
    client,
    reporter,
    packageName,
  });

  // Rename place to reflect current package + commit
  const placeName = await buildPlaceNameAsync(packagePath);
  await tryRenamePlaceAsync(target.placeId, placeName);

  // Read the test script (or use provided scriptText)
  const scriptContent =
    scriptText ?? (await readTestScriptAsync(packagePath, target.scriptTemplate));

  // Execute script via Open Cloud
  reporter.onPackagePhaseChange(packageName, 'scheduling');
  const task = await client.createExecutionTaskAsync(
    target.universeId,
    target.placeId,
    version,
    scriptContent
  );

  // Poll with timeout
  const completedTask = await Promise.race([
    client.pollTaskCompletionAsync(task.path, (state) => {
      if (state === 'PROCESSING') {
        reporter.onPackagePhaseChange(packageName, 'executing');
      }
    }),
    timeoutAsync(timeoutMs, `Test timed out after ${timeoutMs / 1000}s`),
  ]);

  const { success, logs } = await client.getTaskLogsAsync(task.path);

  const taskCompleted = completedTask.state === 'COMPLETE';
  const finalLogs = taskCompleted
    ? logs
    : [logs, `Task ended with state: ${completedTask.state}`]
        .filter(Boolean)
        .join('\n');

  return {
    success: taskCompleted && success,
    logs: finalLogs,
  };
}

/**
 * Build a place via rojo and run tests locally via studio-bridge.
 */
export async function runSingleLocalTestAsync(
  options: SingleTestOptions
): Promise<SingleTestResult> {
  const {
    packagePath,
    reporter,
    packageName,
    timeoutMs = 120_000,
    scriptText,
  } = options;

  const sessionId = randomUUID();

  const { rbxlPath, target } = await buildPlaceAsync({
    targetName: 'test',
    outputFileName: `test-${sessionId}.rbxl`,
    packagePath,
    reporter,
    packageName,
  });

  // Read script content into a string
  let scriptContent: string;
  if (scriptText) {
    scriptContent = scriptText;
  } else {
    if (!target.scriptTemplate) {
      throw new Error(
        `No scriptTemplate configured for test target in ${packagePath}. Add a "scriptTemplate" field to your deploy.nevermore.json test target.`
      );
    }
    const scriptFullPath = path.resolve(packagePath, target.scriptTemplate);
    scriptContent = await fs.readFile(scriptFullPath, 'utf-8');
  }

  reporter.onPackagePhaseChange(packageName, 'executing');

  // Execute via studio-bridge
  let result;
  const bridge = new StudioBridge({ placePath: rbxlPath, timeoutMs, sessionId });
  try {
    await bridge.startAsync();
    result = await bridge.executeAsync({ scriptContent });
  } catch (error) {
    const errorMessage =
      error instanceof Error ? error.message : String(error);
    result = {
      success: false,
      logs: `[StudioBridge] Error: ${errorMessage}`,
    };
  } finally {
    await bridge.stopAsync();
    // Clean up session-specific place file and Studio's lock file
    await Promise.all([
      fs.unlink(rbxlPath).catch(() => {}),
      fs.unlink(`${rbxlPath}.lock`).catch(() => {}),
    ]);
  }

  const parsed = parseTestLogs(result.logs);

  return {
    success: result.success && parsed.success,
    logs: parsed.logs,
  };
}

/**
 * Read a test script from the deploy target's configured script path.
 */
export async function readTestScriptAsync(
  packagePath: string,
  scriptPath: string | undefined
): Promise<string> {
  if (!scriptPath) {
    throw new Error(
      `No scriptTemplate configured for test target in ${packagePath}. Add a "scriptTemplate" field to your deploy.nevermore.json test target.`
    );
  }

  const fullPath = path.resolve(packagePath, scriptPath);
  try {
    return await fs.readFile(fullPath, 'utf-8');
  } catch {
    throw new Error(`Test script not found: ${fullPath}`);
  }
}
