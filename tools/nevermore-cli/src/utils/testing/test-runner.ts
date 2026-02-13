import * as fs from 'fs/promises';
import * as path from 'path';
import { OpenCloudClient } from '../open-cloud/open-cloud-client.js';
import { tryRenamePlaceAsync } from '../auth/roblox-auth/index.js';
import { buildPlaceNameAsync, timeoutAsync } from '../nevermore-cli-utils.js';
import { buildAndUploadAsync } from '../build/build-and-upload.js';

export type TestPhase = 'building' | 'uploading' | 'scheduling' | 'executing';

export interface SingleTestResult {
  success: boolean;
  logs: string;
  taskState: string;
  version: number;
  placeId: number;
}

/**
 * Build, upload, and run a test for a single package.
 * Returns a structured result — no process.exit, no console output beyond
 * what buildAndUploadAsync and OpenCloudClient emit.
 */
export async function runSingleTestAsync(
  packagePath: string,
  client: OpenCloudClient,
  timeoutMs: number = 120_000,
  onPhaseChange?: (phase: TestPhase) => void
): Promise<SingleTestResult> {
  const result = await buildAndUploadAsync(
    { dryrun: false },
    'test',
    'test.rbxl',
    packagePath,
    client,
    onPhaseChange
  );

  if (!result) {
    throw new Error('Unexpected: buildAndUploadAsync returned undefined in non-dryrun mode');
  }

  const { target, version } = result;

  // Rename place to reflect current package + commit
  const placeName = await buildPlaceNameAsync(packagePath);
  await tryRenamePlaceAsync(target.placeId, placeName);

  // Read the test script
  const scriptContent = await readTestScriptAsync(packagePath, target.scriptTemplate);

  // Execute script via Open Cloud
  onPhaseChange?.('scheduling');
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
        onPhaseChange?.('executing');
      }
    }),
    timeoutAsync(timeoutMs, `Test timed out after ${timeoutMs / 1000}s`),
  ]);

  const { success, logs } = await client.getTaskLogsAsync(task.path);

  return {
    success: completedTask.state === 'COMPLETE' && success,
    logs,
    taskState: completedTask.state,
    version,
    placeId: target.placeId,
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
