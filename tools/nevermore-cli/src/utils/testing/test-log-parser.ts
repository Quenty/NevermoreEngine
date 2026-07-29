import { OutputHelper } from '@quenty/cli-output-helpers';

export interface ParsedTestCounts {
  passed: number;
  failed: number;
  total: number;
}

export interface ParsedTestLogs {
  success: boolean;
  logs: string;
  testCounts?: ParsedTestCounts;
  /** Why the run is not a pass. Empty when it is. */
  failureReasons: string[];
}

export interface TestOutcomeOptions {
  /**
   * Require proof the runner ran. Off for probe scripts (--script-text), which
   * legitimately produce no jest report.
   */
  requireTestReport?: boolean;
}

/**
 * Decide whether test output represents a pass, and say why when it does not.
 *
 * The single definition of the rule. Both the single-package path and the batch
 * path route through here — they previously carried divergent copies that
 * disagreed about tracebacks, so the same commit could pass one and fail the
 * other.
 */
export function evaluateTestOutcome(
  rawOutput: string,
  options: TestOutcomeOptions = {}
): { success: boolean; failureReasons: string[] } {
  const cleanLogs = OutputHelper.stripAnsi(rawOutput);
  const failureReasons: string[] = [];

  const failedSuites = cleanLogs.match(/Test Suites:\s*(\d+)\s+failed/);
  const failedTests = cleanLogs.match(/Tests:\s*(\d+)\s+failed/);
  if (failedSuites && parseInt(failedSuites[1], 10) > 0) {
    failureReasons.push(`${failedSuites[1]} test suite(s) failed`);
  }
  if (failedTests && parseInt(failedTests[1], 10) > 0) {
    failureReasons.push(`${failedTests[1]} test(s) failed`);
  }

  // Tracebacks always fail. They catch use-after-free bugs that jest cannot
  // see, since a deferred-callback crash fires outside any test.
  const tracebacks = countTracebacks(cleanLogs);
  if (tracebacks > 0) {
    failureReasons.push(
      `${tracebacks} Luau traceback(s) — see attributed errors below`
    );
  }

  if (options.requireTestReport && !hasTestReport(cleanLogs)) {
    failureReasons.push(
      'no jest report in output — nothing proves any test ran'
    );
  }

  return { success: failureReasons.length === 0, failureReasons };
}

/**
 * True when jest reported at all, including reporting that it found nothing.
 *
 * "Ran and found no tests" is a legitimate answer for packages that ship
 * without specs; "we never heard from jest" is not. Keying on the report
 * rather than on a test count keeps `passWithNoTests` working.
 */
export function hasTestReport(rawOutput: string): boolean {
  const clean = OutputHelper.stripAnsi(rawOutput);
  return (
    /Tests:\s+/.test(clean) ||
    /Test Suites:\s+/.test(clean) ||
    /No tests found/i.test(clean)
  );
}

/** Count Luau tracebacks in output. */
export function countTracebacks(rawOutput: string): number {
  if (!rawOutput) {
    return 0;
  }
  return OutputHelper.stripAnsi(rawOutput).match(/Stack Begin\s/g)?.length ?? 0;
}

/**
 * Analyze test output for Jest failures and Luau runtime errors.
 * Shared by both Open Cloud log fetching and local run-in-roblox output.
 */
export function parseTestLogs(
  rawOutput: string,
  options: TestOutcomeOptions = {}
): ParsedTestLogs {
  const outcome = evaluateTestOutcome(rawOutput, options);

  return {
    success: outcome.success,
    failureReasons: outcome.failureReasons,
    logs: rawOutput,
    testCounts: parseTestCounts(rawOutput),
  };
}

/**
 * Parse Jest "Tests: N failed, N passed, N total" line into structured counts.
 * Returns undefined if no test summary line is found.
 */
export function parseTestCounts(
  rawOutput: string
): ParsedTestCounts | undefined {
  const clean = OutputHelper.stripAnsi(rawOutput);

  // Match "Tests:  2 failed, 23 passed, 25 total" or "Tests:  25 passed, 25 total"
  const match = clean.match(/Tests:\s+(.+?)\s+total/);
  if (!match) return undefined;

  const prefix = match[1];
  const totalMatch = clean.match(/Tests:\s+.+?(\d+)\s+total/);
  if (!totalMatch) return undefined;

  const total = parseInt(totalMatch[1], 10);
  const passedMatch = prefix.match(/(\d+)\s+passed/);
  const failedMatch = prefix.match(/(\d+)\s+failed/);

  const passed = passedMatch ? parseInt(passedMatch[1], 10) : 0;
  const failed = failedMatch ? parseInt(failedMatch[1], 10) : 0;

  return { passed, failed, total };
}
