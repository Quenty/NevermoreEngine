import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type ParsedTestCounts,
  evaluateTestOutcome,
  parseTestCounts,
} from '../test-log-parser.js';
import { formatTracebacks, parseTracebacks } from './traceback-parser.js';
import { type StructuredTestResults } from '../structured-test-results.js';
import { describeLogVolume, type LogFetchStats } from '../log-fetch-stats.js';

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
  /**
   * Where `testCounts` came from. `returned` means the run handed them over as a
   * value; `scraped` means they were read out of log text, which is the channel
   * truncation destroys. Absent when there are no counts at all.
   *
   * Recorded because the two are otherwise indistinguishable in the output, and
   * a structured channel that quietly stopped flowing looks exactly like one
   * that never existed.
   */
  countsSource?: 'returned' | 'scraped';
  /**
   * What this package's own run returned, recovered from the batch summary.
   *
   * One execution covers every package, so its return value belongs to none of
   * them — the batch runner splits the per-package results into the summary
   * instead, and this puts them back in the shape a single run's results have.
   * Lossy by design: the summary carries counts, not failure text, which is
   * per-package and already in that package's log section.
   */
  testResults?: StructuredTestResults;
}

export interface ParseBatchTestLogsOptions {
  /**
   * What the fetch that produced `rawLogs` had to do to collect them, when the
   * caller knows. Not used to judge a package — it only tells a failure that
   * has already happened how much of the run's output ever arrived.
   */
  logFetchStats?: LogFetchStats;
}

const BEGIN_MARKER = '===BATCH_TEST_BEGIN ';
const END_MARKER = '===BATCH_TEST_END ';
const SUMMARY_MARKER = '===BATCH_TEST_SUMMARY===';

/**
 * Counts the batch runner folds in from what a package's test script returned.
 *
 * Present only for a package whose script returns its results. Carried in the
 * summary rather than left to the logs because the summary prints last and
 * survives a truncated log window, which is where scraped counts are lost.
 */
interface SummaryCounts {
  passed: number;
  failed: number;
  skipped: number;
  total: number;
  suitesPassed: number;
  suitesFailed: number;
  suitesTotal: number;
}

interface SummaryEntry {
  slug: string;
  success: boolean;
  durationMs?: number;
  error?: string;
  counts?: SummaryCounts;
  /** False for a smoke test, so zero counts are not read as "no tests found". */
  ranJest?: boolean;
}

/** Read counts off a summary entry, ignoring anything malformed. */
function readSummaryCounts(entry: SummaryEntry): SummaryCounts | undefined {
  const counts = entry.counts;
  if (typeof counts !== 'object' || counts === null) {
    return undefined;
  }

  const fields: (keyof SummaryCounts)[] = [
    'passed',
    'failed',
    'skipped',
    'total',
    'suitesPassed',
    'suitesFailed',
    'suitesTotal',
  ];
  for (const field of fields) {
    if (!Number.isFinite(counts[field])) {
      return undefined;
    }
  }
  return counts;
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
  slugMap: Map<string, string>,
  options: ParseBatchTestLogsOptions = {}
): Map<string, BatchPackageResult> {
  const results = new Map<string, BatchPackageResult>();
  const lines = rawLogs.split('\n');
  // Reported by every diagnostic below. Each of them is some form of "the
  // output is not what this run should have produced", and none can tell how
  // much of it never arrived without knowing what the fetch collected.
  const logVolume = describeLogVolume(rawLogs, options.logFetchStats);

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
  /** True between the summary marker and its JSON payload. */
  let summaryPayloadPending = false;
  let beginMarkersSeen = 0;
  let endMarkersSeen = 0;
  let strayEndMarkers = 0;
  /** Only one section can have lost its head: the one the log was cut inside. */
  let headSectionClaimed = false;

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

      // A section normally closes on the END matching its own BEGIN.
      const closesOwnSection = endSlug === currentSlug;

      // Open Cloud keeps only the tail of a long run's log, so BEGIN — printed
      // first — can be lost while END and the summary survive. Recovering that
      // means letting an END with no open section claim what precedes it, but
      // only where the head can actually have been dropped: before any BEGIN
      // has survived, and only once. Past that point the log is well-formed,
      // and a BEGIN-less END is a message delivered out of order (the API does
      // not order them), which must not be allowed to claim another package's
      // output.
      const closesDroppedHead =
        currentSlug === null && beginMarkersSeen === 0 && !headSectionClaimed;

      if (closesOwnSection || closesDroppedHead) {
        logSections.set(endSlug, currentLines.join('\n'));
        if (closesDroppedHead) {
          partialSections.add(endSlug);
          headSectionClaimed = true;
        }
        if (durationStr !== undefined) {
          markerDurations.set(endSlug, parseInt(durationStr, 10));
        }
        currentSlug = null;
        currentLines = [];
      } else {
        // Reordered marker from another package. Ignore it without resetting
        // state, so the section it interrupted still closes on its own END.
        strayEndMarkers++;
      }
      continue;
    }

    if (trimmed === SUMMARY_MARKER) {
      // Keep scanning: the summary prints last but is not always delivered last,
      // and a section's END can follow it.
      if (summaryLineIndex < 0) {
        summaryLineIndex = i;
      }
      summaryPayloadPending = true;
      continue;
    }

    // The summary's JSON payload belongs to no section.
    if (summaryPayloadPending && trimmed.trimStart().startsWith('[')) {
      summaryPayloadPending = false;
      continue;
    }

    // Accumulate unconditionally: output that precedes the first surviving
    // BEGIN still belongs to whichever package's END closes it.
    currentLines.push(lines[i]);
  }

  // ── Pass 2: Parse the JSON summary for authoritative pcall results ──

  const summaryResults = new Map<string, boolean>();
  const summaryDurations = new Map<string, number>();
  const summaryErrors = new Map<string, string>();
  const summaryCounts = new Map<string, SummaryCounts>();
  const summaryRanJest = new Map<string, boolean>();
  if (summaryLineIndex >= 0 && summaryLineIndex + 1 < lines.length) {
    const entries = findSummaryEntries(lines, summaryLineIndex + 1);
    if (entries === undefined) {
      OutputHelper.verbose(
        `[batch-log-parser] Failed to parse JSON summary after line ${summaryLineIndex}: ` +
          lines
            .slice(summaryLineIndex + 1, summaryLineIndex + 3)
            .join('\n')
            .slice(0, 200)
      );
    } else {
      for (const entry of entries) {
        summaryResults.set(entry.slug, entry.success);
        if (typeof entry.durationMs === 'number') {
          summaryDurations.set(entry.slug, entry.durationMs);
        }
        if (typeof entry.error === 'string' && entry.error.length > 0) {
          summaryErrors.set(entry.slug, entry.error);
        }
        const counts = readSummaryCounts(entry);
        if (counts) {
          summaryCounts.set(entry.slug, counts);
          summaryRanJest.set(entry.slug, entry.ranJest === true);
        }
      }
      // Log any failures the Luau template reported
      const failures = entries.filter((e) => !e.success);
      if (failures.length > 0) {
        console.error(
          `[batch-log-parser] Luau runner failures: ${JSON.stringify(failures)}`
        );
      }
      console.error(
        `[batch-log-parser] Parsed ${entries.length} summary entries, ${failures.length} reported failures`
      );
    }
  }

  // ── Warn when the batch produced no recognizable output ──

  if (strayEndMarkers > 0) {
    OutputHelper.verbose(
      `[batch-log-parser] Ignored ${strayEndMarkers} out-of-order END marker(s); ` +
        'their sections closed on their own boundaries.'
    );
  }

  const noOutputAtAll = logSections.size === 0 && summaryResults.size === 0;
  if (noOutputAtAll) {
    OutputHelper.warn(
      `[batch-log-parser] No batch markers or summary found in logs (${logVolume}). ` +
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
      `[batch-log-parser] Received output but could not attribute any of it to ` +
        `a package section (${logVolume}; ${beginMarkersSeen} BEGIN, ` +
        `${endMarkersSeen} END markers; summary at line ${summaryLineIndex} of ` +
        `${lines.length}). ` +
        'Test counts are not derived from unattributed output.'
    );
    // BEGIN is printed first and the summary last, so their positions separate
    // the two ways this happens: a log window that dropped the head keeps the
    // summary at the end, while reordered messages put it early.
    OutputHelper.warn(
      summaryLineIndex >= lines.length - 2
        ? '[batch-log-parser] Summary sits at the end of the log — consistent with the head being dropped by a log size/retention limit.'
        : '[batch-log-parser] Summary sits early in the log — consistent with messages delivered out of order.'
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

  /** Packages whose run returned its counts, and those left to log scraping. */
  const structuredSlugs: string[] = [];
  const scrapedSlugs: string[] = [];
  /** Packages reported as failed by a run whose counts show nothing failed. */
  const unexplainedFailures: string[] = [];
  /** Packages judged on returned counts alone, their log section having been lost. */
  const sectionlessButCounted: string[] = [];

  for (const [packageName, slug] of slugMap) {
    const attributedLogs = logSections.get(slug);
    let sectionLogs = attributedLogs ?? '';
    if (!attributedLogs && fallbackLogs && !unattributedClaimed) {
      sectionLogs = fallbackLogs;
      unattributedClaimed = true;
    }
    const summarySuccess = summaryResults.get(slug);
    const counts = summaryCounts.get(slug);
    const reasons: string[] = [];

    // The summary verdict is a floor, not the whole verdict — everything below
    // can fail a run it called successful. It covers both a script that threw
    // and one whose returned results said it failed, so the reason comes from
    // the runner rather than being guessed at here.
    let success = summarySuccess ?? false;
    if (summarySuccess === false) {
      reasons.push(
        summaryErrors.get(slug) ?? 'the batch runner reported this as failed'
      );
    } else if (summarySuccess === undefined) {
      // Absent from the summary is a different fault from failing in it, and
      // conflating them sends you hunting for a Luau error that never happened.
      reasons.push('this package is missing from the batch summary');
    }

    // Returned counts are structural, so a summary that called this a pass
    // while reporting failed tests is not believed — no log line involved.
    if (success && counts && (counts.failed > 0 || counts.suitesFailed > 0)) {
      success = false;
      reasons.push(
        `the batch summary reported a pass alongside ${counts.failed} failed ` +
          `test(s) and ${counts.suitesFailed} failed test suite(s)`
      );
    }

    // The reverse contradiction: failure reported over counts where nothing
    // failed. Left as a failure but said out loud — a runner reading the wrong
    // field produces exactly this, for every package at once.
    if (
      !success &&
      counts &&
      counts.failed === 0 &&
      counts.suitesFailed === 0
    ) {
      unexplainedFailures.push(slug);
    }

    if (attributedLogs !== undefined) {
      // Demanding a jest report in the section is a stand-in for proof the
      // runner ran, and it is the first thing a truncated log window costs.
      // Returned counts are that proof directly, so they retire the stand-in —
      // without this the whole structured channel changed nothing in a CI batch,
      // where dozens of packages share one log window and a section keeps its
      // END marker long after its jest summary was dropped.
      const outcome = evaluateTestOutcome(attributedLogs, {
        requireTestReport: counts === undefined,
      });
      if (!outcome.success) {
        success = false;
        reasons.push(...outcome.failureReasons);
      }
    } else if (counts === undefined) {
      // Judged unreadable rather than judged by content: whatever broke
      // attribution is reason enough not to trust which package a line is from.
      success = false;
      reasons.push(
        `no output could be attributed to this package ` +
          `(${logVolume}; ${beginMarkersSeen} BEGIN markers found)`
      );
    } else {
      // The counts say what happened even though the log does not. Tracebacks
      // cannot be checked without the text, though, so this is a narrower
      // verdict than a package with a section gets — hence the warning.
      sectionlessButCounted.push(slug);
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

    // Counts the runner returned outrank counts scraped from the section: the
    // same numbers when the log survived, real numbers when it did not.
    const scrapedCounts = attributedLogs
      ? parseTestCounts(attributedLogs)
      : undefined;
    const testCounts = counts
      ? { passed: counts.passed, failed: counts.failed, total: counts.total }
      : scrapedCounts;
    const countsSource = counts
      ? ('returned' as const)
      : scrapedCounts
      ? ('scraped' as const)
      : undefined;

    if (counts) {
      structuredSlugs.push(slug);
    } else {
      scrapedSlugs.push(slug);
    }

    // Two channels reporting the same run must agree. When they do not, one of
    // them is lying about what happened and neither total can be trusted on its
    // own — said out loud because a returned count that is quietly wrong reads
    // like a clean run, which is how a broken structured read stays invisible.
    if (counts && scrapedCounts && counts.total !== scrapedCounts.total) {
      OutputHelper.warn(
        `[batch-log-parser] ${slug}: returned counts disagree with the log — ` +
          `the run returned ${counts.passed} passed / ${counts.failed} failed / ` +
          `${counts.total} total, its jest report says ${scrapedCounts.passed} / ` +
          `${scrapedCounts.failed} / ${scrapedCounts.total}. Reporting the returned ` +
          `counts; one of the two channels is wrong.`
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
      countsSource,
      testResults: counts
        ? {
            success: summarySuccess === true,
            ranJest: summaryRanJest.get(slug) === true,
            ...counts,
            failures: [],
            omittedFailures: 0,
            error: summaryErrors.get(slug),
          }
        : undefined,
      error,
    });
  }

  reportCountsProvenance(
    structuredSlugs,
    scrapedSlugs,
    unexplainedFailures,
    sectionlessButCounted
  );

  return results;
}

/**
 * Say where this batch's counts came from, every run.
 *
 * The structured channel exists because Open Cloud truncates a long run's logs.
 * A channel that is plumbed but not flowing produces output identical to one
 * that is working, so silence here is not evidence of anything — the count is
 * stated unconditionally and the fallback is a warning, not a debug line.
 */
function reportCountsProvenance(
  structuredSlugs: string[],
  scrapedSlugs: string[],
  unexplainedFailures: string[],
  sectionlessButCounted: string[]
): void {
  const total = structuredSlugs.length + scrapedSlugs.length;
  if (total === 0) {
    return;
  }

  // Not a failure — this is the case the structured channel was built for — but
  // these packages were judged without their log text, so nothing checked them
  // for tracebacks, which jest cannot count and only the log shows.
  if (sectionlessButCounted.length > 0) {
    OutputHelper.warn(
      `[batch-log-parser] ${sectionlessButCounted.length} package(s) were judged on ` +
        `their returned counts alone, with no log section to read: ` +
        `${sectionlessButCounted.join(
          ', '
        )}. Their counts are exact; they were ` +
        `not checked for Luau tracebacks, which only the log shows.`
    );
  }

  OutputHelper.info(
    `[batch-log-parser] Counts returned by the run for ${structuredSlugs.length} ` +
      `of ${total} package(s); ${scrapedSlugs.length} scraped from logs.`
  );

  // Failing every package while every package's counts are clean is a signature,
  // not a coincidence: it means the runner's verdict, not the tests, is wrong.
  if (unexplainedFailures.length > 0) {
    OutputHelper.warn(
      `[batch-log-parser] ${unexplainedFailures.length} of ${total} package(s) were ` +
        `failed by a run whose own counts show nothing failed: ` +
        `${unexplainedFailures.join(
          ', '
        )}. The failures stand — a runner may know ` +
        `something its counts cannot express — but a verdict no count supports is ` +
        `far more likely to be the runner reading the wrong field.`
    );
  }

  if (scrapedSlugs.length > 0) {
    OutputHelper.warn(
      `[batch-log-parser] ${scrapedSlugs.length} package(s) returned no test ` +
        `results, so their counts were scraped from log text — the channel Open ` +
        `Cloud truncates on long runs: ${scrapedSlugs.join(
          ', '
        )}. Their test ` +
        `script should end with "return results" (see docs/testing/testing.md).`
    );
  }
}

/**
 * Find the summary array in the lines following the summary marker.
 *
 * The marker is printed last, but the API does not deliver messages in order,
 * so unrelated output can land after it. Treating everything past the marker as
 * one JSON blob therefore fails intermittently — the same batch parses on one
 * run and not the next. Scan for the array instead of assuming it is alone.
 */
export function findSummaryEntries(
  lines: string[],
  startIndex: number
): SummaryEntry[] | undefined {
  const MAX_SPAN = 50;

  for (let i = startIndex; i < lines.length; i++) {
    if (!lines[i].trim().startsWith('[')) {
      continue;
    }

    // Normally one line, but allow the array to span a few in case the runner
    // or the transport breaks it up.
    for (let end = i; end < Math.min(lines.length, i + MAX_SPAN); end++) {
      try {
        const parsed = JSON.parse(
          lines
            .slice(i, end + 1)
            .join('\n')
            .trim()
        );
        if (Array.isArray(parsed)) {
          return parsed as SummaryEntry[];
        }
      } catch {
        // Incomplete so far — grow the window and try again.
      }
    }
  }

  return undefined;
}

export { countTracebacks } from '../test-log-parser.js';
