export interface ParsedTestLogs {
  success: boolean;
  logs: string;
}

/**
 * Analyze test output for Jest failures and Luau runtime errors.
 * Shared by both Open Cloud log fetching and local run-in-roblox output.
 */
export function parseTestLogs(rawOutput: string): ParsedTestLogs {
  const cleanLogs = rawOutput.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '');

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
  };
}
