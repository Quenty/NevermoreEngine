import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type ParsedTestCounts,
  evaluateTestOutcome,
  parseTestCounts,
} from '../test-log-parser.js';
import { formatTracebacks, parseTracebacks } from './traceback-parser.js';

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
  /** Sections closed by an END whose BEGIN never arrived — start of output lost. */
  const partialSections = new Set<string>();
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

      // Close on END, not on a matching BEGIN. Open Cloud keeps only the tail
      // of a long run's log, so BEGIN — printed first — is the first thing
      // lost, while END and the summary always survive. Everything since the
      // last boundary belongs to the package this END names.
      if (currentSlug === null || endSlug === currentSlug) {
        logSections.set(endSlug, currentLines.join('\n'));
        if (currentSlug === null) {
          partialSections.add(endSlug);
        }
        if (durationStr !== undefined) {
          markerDurations.set(endSlug, parseInt(durationStr, 10));
        }
      }
      currentSlug = null;
      currentLines = [];
      continue;
    }

    if (trimmed === SUMMARY_MARKER) {
      summaryLineIndex = i;
      break;
    }

    // Accumulate unconditionally: output that precedes the first surviving
    // BEGIN still belongs to whichever package's END closes it.
    currentLines.push(lines[i]);
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
    const reasons: string[] = [];

    // The pcall result only proves the script did not throw. It is a floor, not
    // a verdict — everything below can fail a run it called successful.
    let success = summarySuccess ?? false;
    if (!success) {
      reasons.push('the batch runner reported a Luau error');
    }

    if (attributedLogs !== undefined) {
      const outcome = evaluateTestOutcome(attributedLogs, {
        requireTestReport: true,
      });
      if (!outcome.success) {
        success = false;
        reasons.push(...outcome.failureReasons);
      }
    } else {
      // Judged unreadable rather than judged by content: whatever broke
      // attribution is reason enough not to trust which package a line is from.
      success = false;
      reasons.push(
        `no output could be attributed to this package ` +
          `(${rawLogs.length} chars received, ${beginMarkersSeen} BEGIN markers found)`
      );
    }

    if (partialSections.has(slug)) {
      OutputHelper.warn(
        `[batch-log-parser] ${slug}: section closed by its END marker with no BEGIN — ` +
          'the start of this output was dropped by the log window, so the section is partial.'
      );
    }

    // Attribute by script path, not by log position: a deferred callback can
    // fire during another package's section.
    const tracebacks = parseTracebacks(sectionLogs);
    const tracebackCount = tracebacks.reduce((sum, t) => sum + t.count, 0);
    const owned = tracebacks.filter((t) => !t.owner || t.owner === slug);
    if (tracebacks.length > owned.length) {
      OutputHelper.verbose(
        `[batch-log-parser] ${slug}: ignored ${
          tracebacks.length - owned.length
        } traceback(s) belonging to other packages`
      );
    }
    if (owned.length > 0) {
      OutputHelper.warn(
        `[batch-log-parser] ${slug}: ${owned.length} distinct traceback(s):\n` +
          formatTracebacks(owned)
      );
    }

    const error = reasons.length > 0 ? reasons.join('; ') : undefined;

    const testCounts = attributedLogs
      ? parseTestCounts(attributedLogs)
      : undefined;
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

export { countTracebacks } from '../test-log-parser.js';
