import * as fs from 'fs/promises';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { type DeployTarget } from '@quenty/nevermore-deploy';
import { type JobContext } from '../../job-context/job-context.js';
import {
  type ParsedTestCounts,
  parseTestLogs,
  parseTestCounts,
} from '../test-log-parser.js';
import {
  findStructuredTestResults,
  structuredFailureReasons,
  toParsedTestCounts,
} from '../structured-test-results.js';
import {
  buildDeployMetadataAttributes,
  gatherGitDeployInfo,
  injectDeployMetadataInPlaceAsync,
  packageUsesManifestAsync,
} from '../../deploy/deploy-metadata.js';
import { readPackageVersionAsync } from '../../nevermore-cli-utils.js';

export interface SingleTestResult {
  success: boolean;
  logs: string;
  testCounts?: ParsedTestCounts;
  /**
   * Inner script execution time, forwarded from the JobContext when it can
   * measure pcall duration directly (aggregated batch mode). Undefined for
   * non-aggregated cloud/local runs — callers should fall back to wall-clock.
   */
  durationMs?: number;
  /** Why the run failed, when the runner can say more than "it failed". */
  error?: string;
}

/**
 * Combine failure reasons from the job context with those read from the logs.
 *
 * In batch mode the context has already evaluated these same logs, so the two
 * sources overlap. Merging on the individual reason keeps the overlap from
 * reading as double the failures.
 */
export function mergeFailureReasons(
  contextError: string | undefined,
  logReasons: string[]
): string[] {
  return [
    ...new Set([
      ...(contextError ? contextError.split('; ') : []),
      ...logReasons,
    ]),
  ];
}

export interface SingleTestOptions {
  packagePath: string;
  packageName: string;
  /**
   * Resolved test place. Callers fan multi-place targets out before reaching
   * here (see flattenToBatchTargets) — the runner never picks places[0] itself.
   */
  target: DeployTarget;
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
    // 300s is the Open Cloud maximum. The old 120s default failed real suites
    // with no jest summary at all, so "--timeout 300" had become folklore
    // everyone had to know before their first useful run.
    timeoutMs = 300_000,
    scriptText,
    target,
  } = options;

  const sessionId = randomUUID();
  const builtPlace = await context.buildPlaceAsync({
    target,
    outputFileName: `test-${sessionId}.rbxl`,
    packagePath,
    packageName,
  });

  // Packages that ship or use the manifest get the same deploy-metadata stamp a
  // real deploy would apply, so their specs can assert the injection actually
  // ran. The per-session build is exclusively ours, so rewrite it in place.
  if (await packageUsesManifestAsync(packagePath)) {
    await injectDeployMetadataInPlaceAsync(
      builtPlace.rbxlPath,
      buildDeployMetadataAttributes(gatherGitDeployInfo(), {
        target: 'test',
        published: false,
        timestamp: new Date().toISOString(),
        placeId: builtPlace.target.placeId,
        universeId: builtPlace.target.universeId,
        packageVersion: await readPackageVersionAsync(packagePath),
      })
    );
  }

  const scriptContent =
    scriptText ??
    (await readTestScriptAsync(packagePath, builtPlace.target.scriptTemplate));

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

    // The runner used to announce a failing suite by throwing, which failed the
    // task. It returns its verdict now, so the verdict has to be read: without
    // this, a failing suite whose report fell outside the truncated log window
    // would come back a pass.
    const structured = findStructuredTestResults(result.returnValues);

    // A probe script is arbitrary Luau with no jest in it, so demanding a test
    // report would fail every --script-text run. Everything else must prove a
    // runner spoke before it can pass — and returned results are that proof,
    // where a scraped report is only what survived truncation.
    const parsed = parseTestLogs(rawLogs, {
      requireTestReport: scriptText === undefined && structured === undefined,
    });

    const reasons = mergeFailureReasons(result.errorMessage, [
      ...(structured ? structuredFailureReasons(structured) : []),
      ...parsed.failureReasons,
    ]);

    return {
      success:
        result.success && parsed.success && (structured?.success ?? true),
      logs: parsed.logs,
      // Returned counts outrank scraped ones: same numbers when the log
      // survived, real numbers when it did not.
      testCounts: structured
        ? toParsedTestCounts(structured)
        : parseTestCounts(parsed.logs),
      durationMs: result.durationMs,
      error: reasons.length > 0 ? reasons.join('; ') : undefined,
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
