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
}

/**
 * Analyze test output for Jest failures and Luau runtime errors.
 * Shared by both Open Cloud log fetching and local run-in-roblox output.
 */
export function parseTestLogs(rawOutput: string): ParsedTestLogs {
  const cleanLogs = OutputHelper.stripAnsi(rawOutput);

  // Check for Jest-style test failures
  const failedSuites = cleanLogs.match(/Test Suites:\s*(\d+)\s+failed/);
  const failedTests = cleanLogs.match(/Tests:\s*(\d+)\s+failed/);
  const hasJestFailures =
    (failedSuites && parseInt(failedSuites[1], 10) > 0) ||
    (failedTests && parseInt(failedTests[1], 10) > 0);

  // Check for Luau runtime errors (stack traces)
  const hasRuntimeError = /Stack Begin\s/.test(cleanLogs);

  return {
    success: !hasJestFailures && !hasRuntimeError,
    logs: rawOutput,
    testCounts: parseTestCounts(rawOutput),
  };
}

/**
 * Parse Jest "Tests: N failed, N passed, N total" line into structured counts.
 * Returns undefined if no test summary line is found.
 */
export function parseTestCounts(rawOutput: string): ParsedTestCounts | undefined {
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
