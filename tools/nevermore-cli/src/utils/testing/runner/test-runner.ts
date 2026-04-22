import * as fs from 'fs/promises';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { type JobContext } from '../../job-context/job-context.js';
import { type ParsedTestCounts, parseTestLogs, parseTestCounts } from '../test-log-parser.js';

export interface SingleTestResult {
  success: boolean;
  logs: string;
  testCounts?: ParsedTestCounts;
}

export interface SingleTestOptions {
  packagePath: string;
  packageName: string;
  timeoutMs?: number;
  /** Luau code to execute directly, bypassing the configured scriptTemplate. */
  scriptText?: string;
}

/**
 * Build, deploy, and run a test for a single package using the provided
 * JobContext. The context determines the execution environment (cloud or local).
 *
 * Creates and releases its own deployment handle — the caller owns the context lifetime.
 */
export async function runSingleTestAsync(
  context: JobContext,
  options: SingleTestOptions
): Promise<SingleTestResult> {
  const {
    packagePath,
    packageName,
    timeoutMs = 120_000,
    scriptText,
  } = options;

  const sessionId = randomUUID();
  const builtPlace = await context.buildPlaceAsync({
    targetName: 'test',
    outputFileName: `test-${sessionId}.rbxl`,
    packagePath,
    packageName,
  });

  const scriptContent =
    scriptText ?? (await readTestScriptAsync(packagePath, builtPlace.target.scriptTemplate));

  const deployment = await context.deployBuiltPlaceAsync({
    builtPlace,
    packageName,
    packagePath,
  });

  try {
    const result = await context.runScriptAsync(deployment, {
      scriptContent,
      packageName,
      timeoutMs,
    });

    const rawLogs = await context.getLogsAsync(deployment);
    const parsed = parseTestLogs(rawLogs);

    return {
      success: result.success && parsed.success,
      logs: parsed.logs,
      testCounts: parseTestCounts(parsed.logs),
    };
  } finally {
    await context.releaseAsync(deployment);
  }
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
