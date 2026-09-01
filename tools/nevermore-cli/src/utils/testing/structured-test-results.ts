import { type ParsedTestCounts } from './test-log-parser.js';

/**
 * Tag NevermoreTestRunnerUtils stamps on the results table a test script
 * returns. A test place also runs probe scripts (`--script-text`) that return
 * whatever they like, so results are recognized by this rather than by shape.
 */
export const TEST_RESULTS_FORMAT = 'nevermore-test-results@1';

/** One failed test, or one suite that failed before its tests could run. */
export interface StructuredTestFailure {
  name: string;
  message?: string;
}

/**
 * What a test run says about itself, returned as a value instead of printed.
 *
 * Open Cloud truncates a long run's logs, so counts scraped out of that text go
 * missing on exactly the runs where they matter most. Mirrors the
 * `TestRunResults` table in `NevermoreTestRunnerUtils`.
 */
export interface StructuredTestResults {
  success: boolean;
  /** False for a smoke test, whose counts are all zero because nothing counted. */
  ranJest: boolean;
  passed: number;
  failed: number;
  /** Pending plus todo. */
  skipped: number;
  total: number;
  suitesPassed: number;
  suitesFailed: number;
  suitesTotal: number;
  /** Capped by the runner; `omittedFailures` says how many did not fit. */
  failures: StructuredTestFailure[];
  omittedFailures: number;
  /** Why the run failed when no individual test can say so. */
  error?: string;
}

function readNumber(source: Record<string, unknown>, key: string): number {
  const value = source[key];
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function readFailures(value: unknown): StructuredTestFailure[] {
  if (!Array.isArray(value)) {
    return [];
  }

  const failures: StructuredTestFailure[] = [];
  for (const entry of value) {
    if (typeof entry !== 'object' || entry === null) {
      continue;
    }
    const record = entry as Record<string, unknown>;
    if (typeof record.name !== 'string') {
      continue;
    }
    failures.push({
      name: record.name,
      message: typeof record.message === 'string' ? record.message : undefined,
    });
  }
  return failures;
}

/**
 * Decode a single returned value into results, or undefined if it is not one.
 *
 * Fields are read defensively rather than trusted: the value crossed a
 * transport, and the two transports spell exotic Luau types differently, so a
 * malformed field must not become a verdict.
 */
export function decodeStructuredTestResults(
  value: unknown
): StructuredTestResults | undefined {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return undefined;
  }

  const record = value as Record<string, unknown>;
  if (record.format !== TEST_RESULTS_FORMAT) {
    return undefined;
  }

  return {
    // Only an explicit `true` is a pass. A results table that lost its verdict
    // in transit must not read as one.
    success: record.success === true,
    ranJest: record.ranJest === true,
    passed: readNumber(record, 'passed'),
    failed: readNumber(record, 'failed'),
    skipped: readNumber(record, 'skipped'),
    total: readNumber(record, 'total'),
    suitesPassed: readNumber(record, 'suitesPassed'),
    suitesFailed: readNumber(record, 'suitesFailed'),
    suitesTotal: readNumber(record, 'suitesTotal'),
    failures: readFailures(record.failures),
    omittedFailures: readNumber(record, 'omittedFailures'),
    error: typeof record.error === 'string' ? record.error : undefined,
  };
}

/**
 * Find the results a run returned, if it returned any.
 *
 * `undefined` covers both "the transport delivered no return channel" and "the
 * script returned nothing recognizable" — a caller falls back to the logs
 * either way, which is what a test script written before this convention gets.
 */
export function findStructuredTestResults(
  returnValues: unknown[] | undefined
): StructuredTestResults | undefined {
  if (!returnValues) {
    return undefined;
  }

  for (const value of returnValues) {
    const results = decodeStructuredTestResults(value);
    if (results) {
      return results;
    }
  }
  return undefined;
}

/**
 * Describe a verdict the run's own counts do not support, for a warning.
 *
 * A run reporting failure while nothing in it failed is self-contradicting, and
 * it is precisely what a runner reading the wrong field produces: the counts
 * stay plausible, so nothing looks wrong except that every package fails at
 * once. That shipped once — a runner consulted jest-lua's inverted
 * `AggregatedResult.success` and failed every passing suite.
 *
 * Reported, never corrected. A runner that says it failed may know something its
 * counts cannot express (an interrupted run, a snapshot check, a reporter
 * error), so the verdict stands and the contradiction is made loud instead.
 */
export function describeUnexplainedVerdict(
  results: StructuredTestResults
): string | undefined {
  if (results.success || results.failed > 0 || results.suitesFailed > 0) {
    return undefined;
  }

  return (
    `the run reports failure but its own counts show nothing failed ` +
    `(${results.passed} passed, 0 failed, ${results.total} total, ` +
    `0 of ${results.suitesTotal} suite(s) failed)` +
    (results.error
      ? `. It says: ${results.error}`
      : ' and gives no reason at all')
  );
}

/** Counts in the shape the reporters already render. */
export function toParsedTestCounts(
  results: StructuredTestResults
): ParsedTestCounts {
  return {
    passed: results.passed,
    failed: results.failed,
    total: results.total,
  };
}

/**
 * Why the runner says the run failed. Empty when it says it passed.
 *
 * Phrased to match the log parser's wording so that merging the two sources
 * collapses the overlap instead of reporting every failure twice.
 */
export function structuredFailureReasons(
  results: StructuredTestResults
): string[] {
  if (results.success) {
    return [];
  }

  const reasons: string[] = [];
  if (results.suitesFailed > 0) {
    reasons.push(`${results.suitesFailed} test suite(s) failed`);
  }
  if (results.failed > 0) {
    reasons.push(`${results.failed} test(s) failed`);
  }

  // The runner's own message restates those two lines when a count explains the
  // failure, so it is only worth repeating when nothing else can say why —
  // an interrupted run, a failed snapshot check, a result shape it could not
  // read. That case is also the one where a reason is most needed.
  if (reasons.length === 0) {
    reasons.push(results.error ?? 'the test runner reported the run as failed');
  }
  return reasons;
}
