import { OutputHelper } from '@quenty/cli-output-helpers';

export interface BatchPackageResult {
  slug: string;
  success: boolean;
  logs: string;
}

const BEGIN_MARKER = '===BATCH_TEST_BEGIN ';
const END_MARKER = '===BATCH_TEST_END ';
const SUMMARY_MARKER = '===BATCH_TEST_SUMMARY===';

interface SummaryEntry {
  slug: string;
  success: boolean;
  error?: string;
}

/**
 * Parse the single batch execution's logs into per-package results.
 *
 * The batch Luau template prints structured markers around each package's output:
 *   ===BATCH_TEST_BEGIN <slug>===
 *   ... test output ...
 *   ===BATCH_TEST_END <slug> PASS|FAIL===
 *   ===BATCH_TEST_SUMMARY===
 *   [{"slug":"maid","success":true}, ...]
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
  let currentSlug: string | null = null;
  let currentLines: string[] = [];
  let summaryLineIndex = -1;

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trimEnd();

    if (trimmed.startsWith(BEGIN_MARKER) && trimmed.endsWith('===')) {
      currentSlug = trimmed.slice(BEGIN_MARKER.length, -3);
      currentLines = [];
      continue;
    }

    if (trimmed.startsWith(END_MARKER) && trimmed.endsWith('===')) {
      const inner = trimmed.slice(END_MARKER.length, -3);
      const spaceIndex = inner.lastIndexOf(' ');
      const endSlug = spaceIndex >= 0 ? inner.slice(0, spaceIndex) : inner;

      if (currentSlug && endSlug === currentSlug) {
        logSections.set(currentSlug, currentLines.join('\n'));
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
  if (summaryLineIndex >= 0 && summaryLineIndex + 1 < lines.length) {
    const jsonLine = lines
      .slice(summaryLineIndex + 1)
      .join('\n')
      .trim();
    try {
      const entries = JSON.parse(jsonLine) as SummaryEntry[];
      for (const entry of entries) {
        summaryResults.set(entry.slug, entry.success);
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
        `[batch-log-parser] Failed to parse JSON summary: ${jsonLine.slice(0, 200)}`
      );
    }
  }

  // ── Pass 3: Combine log sections with summary results ──

  for (const [packageName, slug] of slugMap) {
    const sectionLogs = logSections.get(slug) ?? '';
    const summarySuccess = summaryResults.get(slug);

    // The JSON summary (pcall result) is the primary success signal.
    // Jest failure detection provides a secondary override.
    let success = summarySuccess ?? false;
    if (success && sectionLogs) {
      const hasJestFailures = _hasJestFailuresInLogs(sectionLogs);
      if (hasJestFailures) {
        success = false;
      }
    }

    if (!success) {
      console.error(
        `[batch-log-parser] ${slug}: summarySuccess=${summarySuccess} hasLogs=${sectionLogs.length > 0} logsLen=${sectionLogs.length}`
      );
    }

    results.set(packageName, { slug, success, logs: sectionLogs });
  }

  return results;
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
