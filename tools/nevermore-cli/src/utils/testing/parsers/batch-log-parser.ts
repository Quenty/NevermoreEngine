import { OutputHelper } from '@quenty/cli-output-helpers';
import { type ParsedTestCounts, parseTestCounts } from '../test-log-parser.js';

export interface BatchPackageResult {
  slug: string;
  success: boolean;
  logs: string;
  /** Inner pcall execution time reported by the Luau batch runner. */
  durationMs?: number;
  testCounts?: ParsedTestCounts;
  /** Why this package failed, when the failure is the parser's own verdict. */
  error?: string;
  /**
   * Luau tracebacks found in this package's section. Reported, not gated on:
   * jest cannot count these, since a deferred-callback crash fires outside any
   * test — often after the test that scheduled it already passed.
   */
  tracebackCount: number;
}

const BEGIN_MARKER = '===BATCH_TEST_BEGIN ';
const END_MARKER = '===BATCH_TEST_END ';
const SUMMARY_MARKER = '===BATCH_TEST_SUMMARY===';

interface SummaryEntry {
  slug: string;
  success: boolean;
  durationMs?: number;
  error?: string;
}

/**
 * Parse the single batch execution's logs into per-package results.
 *
 * The batch Luau template prints structured markers around each package's output:
 *   ===BATCH_TEST_BEGIN <slug>===
 *   ... test output ...
 *   ===BATCH_TEST_END <slug> PASS|FAIL <durationMs>===
 *   ===BATCH_TEST_SUMMARY===
 *   [{"slug":"maid","success":true,"durationMs":1234}, ...]
 *
 * Success is determined from the JSON summary (based on pcall results), which is
 * immune to log reordering. The BEGIN/END markers are used only for splitting logs
 * into per-package sections. Jest failure detection provides a secondary override.
 */
export function parseBatchTestLogs(
  rawLogs: string,
  slugMap: Map<string, string>
): Map<string, BatchPackageResult> {
  const results = new Map<string, BatchPackageResult>();
  const lines = rawLogs.split('\n');

  // Build reverse map: slug → packageName
  const slugToPackage = new Map<string, string>();
  for (const [packageName, slug] of slugMap) {
    slugToPackage.set(slug, packageName);
  }

  // ── Pass 1: Extract per-package log sections from markers ──

  const logSections = new Map<string, string>();
  const markerDurations = new Map<string, number>();
  let currentSlug: string | null = null;
  let currentLines: string[] = [];
  let summaryLineIndex = -1;
  let beginMarkersSeen = 0;
  let endMarkersSeen = 0;

  // Matches "<slug> PASS|FAIL [<durationMs>]" — slugs have no whitespace.
  const endInnerPattern = /^(\S+)\s+(?:PASS|FAIL)(?:\s+(\d+))?$/;

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trimEnd();

    if (trimmed.startsWith(BEGIN_MARKER) && trimmed.endsWith('===')) {
      currentSlug = trimmed.slice(BEGIN_MARKER.length, -3);
      currentLines = [];
      beginMarkersSeen++;
      continue;
    }

    if (trimmed.startsWith(END_MARKER) && trimmed.endsWith('===')) {
      const inner = trimmed.slice(END_MARKER.length, -3);
      endMarkersSeen++;
      const match = endInnerPattern.exec(inner);
      const endSlug = match ? match[1] : inner;
      const durationStr = match?.[2];

      if (currentSlug && endSlug === currentSlug) {
        logSections.set(currentSlug, currentLines.join('\n'));
        if (durationStr !== undefined) {
          markerDurations.set(currentSlug, parseInt(durationStr, 10));
        }
        currentSlug = null;
        currentLines = [];
      }
      // If endSlug doesn't match currentSlug, this is a reordered marker
      // from another package — ignore it without resetting state.
      continue;
    }

    if (trimmed === SUMMARY_MARKER) {
      summaryLineIndex = i;
      break;
    }

    if (currentSlug) {
      currentLines.push(lines[i]);
    }
  }

  // ── Pass 2: Parse the JSON summary for authoritative pcall results ──

  const summaryResults = new Map<string, boolean>();
  const summaryDurations = new Map<string, number>();
  if (summaryLineIndex >= 0 && summaryLineIndex + 1 < lines.length) {
    const jsonLine = lines
      .slice(summaryLineIndex + 1)
      .join('\n')
      .trim();
    try {
      const entries = JSON.parse(jsonLine) as SummaryEntry[];
      for (const entry of entries) {
        summaryResults.set(entry.slug, entry.success);
        if (typeof entry.durationMs === 'number') {
          summaryDurations.set(entry.slug, entry.durationMs);
        }
      }
      // Log any pcall failures from the Luau template
      const failures = entries.filter((e) => !e.success);
      if (failures.length > 0) {
        console.error(
          `[batch-log-parser] Luau pcall failures: ${JSON.stringify(failures)}`
        );
      }
      console.error(
        `[batch-log-parser] Parsed ${entries.length} summary entries, ${failures.length} failures`
      );
    } catch {
      OutputHelper.verbose(
        `[batch-log-parser] Failed to parse JSON summary: ${jsonLine.slice(
          0,
          200
        )}`
      );
    }
  }

  // ── Warn when the batch produced no recognizable output ──

  const noOutputAtAll = logSections.size === 0 && summaryResults.size === 0;
  if (noOutputAtAll) {
    OutputHelper.warn(
      `[batch-log-parser] No batch markers or summary found in logs (${lines.length} lines, ${rawLogs.length} chars). ` +
        'The batch script may not have started or produced output.'
    );
  }

  // The summary is printed last, so it survives a log fetch that dropped the
  // output above it. Summary present with no sections is exactly that case, and
  // it is invisible to the check above — the results below would then be built
  // from pcall exit status alone, knowing nothing about what actually ran.
  const lostSectionOutput = logSections.size === 0 && summaryResults.size > 0;
  if (lostSectionOutput) {
    OutputHelper.warn(
      `[batch-log-parser] Received ${rawLogs.length} chars of output but could not ` +
        `attribute any of it to a package section ` +
        `(${beginMarkersSeen} BEGIN, ${endMarkersSeen} END markers; summary at line ` +
        `${summaryLineIndex} of ${lines.length}). ` +
        'Test counts are not derived from unattributed output.'
    );
    // BEGIN is printed first and the summary last, so their positions separate
    // the two ways this happens: a log window that dropped the head keeps the
    // summary at the end, while reordered messages put it early.
    OutputHelper.warn(
      summaryLineIndex >= lines.length - 2
        ? '[batch-log-parser] Summary sits at the end of the log — consistent with the head being dropped by a log size/retention limit.'
        : '[batch-log-parser] Summary sits early in the log — consistent with out-of-order messages ending the scan prematurely.'
    );
  }

  // ── Pass 3: Combine log sections with summary results ──

  // Output that arrived but could not be split into sections is still output.
  // Reporting "(no output)" over it hides the very thing needed to diagnose the
  // parse failure, so it is shown verbatim instead. Only safe to hand to a
  // single package: with several, there is no way to say whose output this is.
  const fallbackLogs = noOutputAtAll || lostSectionOutput ? rawLogs.trim() : '';

  // The unattributed stream is the same text for every package, so it is
  // attached once rather than repeated per package across a large log.
  let unattributedClaimed = false;

  for (const [packageName, slug] of slugMap) {
    const attributedLogs = logSections.get(slug);
    let sectionLogs = attributedLogs ?? '';
    if (!attributedLogs && fallbackLogs && !unattributedClaimed) {
      sectionLogs = fallbackLogs;
      unattributedClaimed = true;
    }
    const summarySuccess = summaryResults.get(slug);

    // The JSON summary (pcall result) is the primary success signal.
    // Jest failure detection provides a secondary override.
    //
    // Gate on attributed output only. Unattributed output is shown but not
    // judged: whatever broke attribution is reason enough not to trust which
    // package a failure line belongs to.
    let success = summarySuccess ?? false;
    let error: string | undefined;
    if (success && attributedLogs) {
      const hasJestFailures = _hasJestFailuresInLogs(attributedLogs);
      if (hasJestFailures) {
        success = false;
        error = 'Jest reported failing tests';
      }
    }

    // A pass we cannot read is not a pass. The pcall only proves the script did
    // not throw, which says nothing about whether any test ran or passed.
    if (success && !attributedLogs) {
      success = false;
      error =
        `No test output could be attributed to this package ` +
        `(${rawLogs.length} chars received, ${beginMarkersSeen} BEGIN markers found). ` +
        'Unattributed output follows.';
    }

    if (!success && !noOutputAtAll) {
      console.error(
        `[batch-log-parser] ${slug}: summarySuccess=${summarySuccess} hasLogs=${
          sectionLogs.length > 0
        } logsLen=${sectionLogs.length}`
      );
    }

    // Deliberately not parsed from unattributed output: attribution is exactly
    // what failed, so a count read from it could belong to anything. The logs
    // are still shown, so the jest summary remains readable by eye.
    const testCounts = attributedLogs
      ? parseTestCounts(attributedLogs)
      : undefined;
    const tracebackCount = countTracebacks(sectionLogs);
    if (tracebackCount > 0) {
      OutputHelper.warn(
        `[batch-log-parser] ${slug}: ${tracebackCount} Luau traceback(s) in output. ` +
          'Jest does not count these — a deferred-callback crash fires outside any test.'
      );
    }
    // Prefer the JSON summary (authoritative, immune to log reordering);
    // fall back to the END-marker value if the summary was truncated.
    const durationMs = summaryDurations.get(slug) ?? markerDurations.get(slug);
    results.set(packageName, {
      slug,
      success,
      logs: sectionLogs,
      durationMs,
      testCounts,
      tracebackCount,
      error,
    });
  }

  return results;
}

/**
 * Count Luau tracebacks in log output.
 *
 * Reported separately from test counts because jest never sees these: a crash in
 * a deferred callback fires outside any test, so a run can print
 * "Tests: 155 passed, 0 failed" while something is genuinely broken.
 */
export function countTracebacks(rawOutput: string): number {
  if (!rawOutput) {
    return 0;
  }
  const cleanLogs = OutputHelper.stripAnsi(rawOutput);
  return cleanLogs.match(/Stack Begin\s/g)?.length ?? 0;
}

/**
 * Check specifically for Jest test suite/test failures in logs.
 * Unlike parseTestLogs, this ignores "Stack Begin" runtime errors since
 * those can come from deferred callbacks of other packages in batch mode.
 */
function _hasJestFailuresInLogs(rawOutput: string): boolean {
  const cleanLogs = OutputHelper.stripAnsi(rawOutput);
  const failedSuites = cleanLogs.match(/Test Suites:\s*(\d+)\s+failed/);
  const failedTests = cleanLogs.match(/Tests:\s*(\d+)\s+failed/);
  return (
    (failedSuites != null && parseInt(failedSuites[1], 10) > 0) ||
    (failedTests != null && parseInt(failedTests[1], 10) > 0)
  );
}
