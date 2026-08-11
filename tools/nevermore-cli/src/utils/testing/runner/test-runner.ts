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
  type StructuredTestResults,
  findStructuredTestResults,
  structuredFailureReasons,
  toParsedTestCounts,
} from '../structured-test-results.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
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
  /**
   * Where `testCounts` came from. `returned` means the run handed them over as a
   * value; `scraped` means they were read out of log text, which is the channel
   * truncation destroys. Absent when there are no counts at all.
   */
  countsSource?: 'returned' | 'scraped';
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
    //
    // A context that already resolved the results (aggregated batch, where one
    // execution's return value belongs to no single package) hands them over
    // directly; otherwise they are decoded from what the script returned.
    const structured =
      result.testResults ?? findStructuredTestResults(result.returnValues);

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

    // Returned counts outrank scraped ones: same numbers when the log
    // survived, real numbers when it did not.
    const scrapedCounts = parseTestCounts(parsed.logs);
    const testCounts = structured
      ? toParsedTestCounts(structured)
      : scrapedCounts;

    reportCountsProvenance({
      packageName,
      structured,
      scrapedCounts,
      // A probe is not a test run, so it has no results to be missing. Neither
      // is one package of an aggregated batch, whose context reported the whole
      // batch's provenance in one line already.
      silent: scriptText !== undefined || result.testResults !== undefined,
      hadReturnChannel: result.returnValues !== undefined,
    });

    return {
      success:
        result.success && parsed.success && (structured?.success ?? true),
      logs: parsed.logs,
      testCounts,
      countsSource: structured
        ? 'returned'
        : scrapedCounts
        ? 'scraped'
        : undefined,
      durationMs: result.durationMs,
      error: reasons.length > 0 ? reasons.join('; ') : undefined,
    };
  } finally {
    await context.releaseAsync(deployment);
  }
}

/**
 * Say where a run's counts came from, and complain when they had to be scraped.
 *
 * The structured channel exists because Open Cloud truncates a long run's logs.
 * A channel that is plumbed but not flowing produces output identical to one
 * that works, so the fallback is a warning rather than silence — the first
 * version of this shipped inert and looked green.
 */
function reportCountsProvenance(options: {
  packageName: string;
  structured?: StructuredTestResults;
  scrapedCounts?: ParsedTestCounts;
  silent: boolean;
  hadReturnChannel: boolean;
}): void {
  const { packageName, structured, scrapedCounts, silent, hadReturnChannel } =
    options;

  if (silent) {
    return;
  }

  if (structured) {
    OutputHelper.info(
      `${packageName}: counts returned by the run — ` +
        `${structured.passed} passed, ${structured.failed} failed, ` +
        `${structured.total} total.`
    );

    // Two channels reporting the same run must agree. When they do not, one is
    // lying and neither total stands on its own.
    if (scrapedCounts && scrapedCounts.total !== structured.total) {
      OutputHelper.warn(
        `${packageName}: returned counts disagree with the log — the run returned ` +
          `${structured.passed}/${structured.failed}/${structured.total} ` +
          `(passed/failed/total), its jest report says ` +
          `${scrapedCounts.passed}/${scrapedCounts.failed}/${scrapedCounts.total}. ` +
          `Reporting the returned counts; one of the two channels is wrong.`
      );
    }
    return;
  }

  OutputHelper.warn(
    `${packageName}: the run returned no test results, so its counts were ` +
      (scrapedCounts ? 'scraped from log text' : 'unavailable') +
      ` — the channel Open Cloud truncates on long runs. ` +
      (hadReturnChannel
        ? 'The run delivered a return channel but nothing recognizable in it: the ' +
          'test script should end with "return results" (see docs/testing/testing.md).'
        : 'No return channel was delivered at all, so the transport lost it.')
  );
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
