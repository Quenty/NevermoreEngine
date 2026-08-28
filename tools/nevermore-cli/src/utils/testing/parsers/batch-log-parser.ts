import { OutputHelper } from '@quenty/cli-output-helpers';
import { isCI } from '@quenty/cli-output-helpers/cli-utils';
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
  /**
   * Where diagnostics go. When set, the parser reports through this instead of
   * printing, so a caller that renders the run's output can hold them until
   * after it: a remark about a log window reads as nonsense above the log it
   * is describing.
   */
  onDiagnostic?: (level: BatchDiagnosticLevel, message: string) => void;
}

/**
 * `group` and `endgroup` bracket a run of diagnostics that belong together, so
 * a finding repeated across many packages can be collapsed into one block
 * instead of one line each.
 */
export type BatchDiagnosticLevel =
  | 'info'
  | 'warn'
  | 'verbose'
  | 'group'
  | 'endgroup';

/**
 * How one package in a listing turned out, phrased as its group title is.
 *
 * Kept short: this is a line in a list of dozens, not a report.
 */
function describeSlugState(
  slug: string,
  results: Map<string, BatchPackageResult>,
  slugMap: Map<string, string>
): string {
  let packageName: string | undefined;
  for (const [name, candidate] of slugMap) {
    if (candidate === slug) {
      packageName = name;
      break;
    }
  }

  const result = packageName ? results.get(packageName) : undefined;
  if (!result) {
    return 'no result';
  }

  const counts = result.testCounts
    ? ` (${result.testCounts.passed}/${result.testCounts.total})`
    : '';
  return `${result.success ? 'Passed' : 'FAILED'}${counts}`;
}

/**
 * Print one diagnostic, honoring the grouping levels.
 *
 * `useGroups` is passed in rather than looked up, so the whole run agrees about
 * whether it is emitting workflow commands. Asking `isCI()` separately here, in
 * the renderer and in the reporter is three answers to one question.
 */
export function emitDiagnostic(
  level: BatchDiagnosticLevel,
  message: string,
  useGroups: boolean
): void {
  if (level === 'group') {
    OutputHelper.startGroup(message, useGroups);
  } else if (level === 'endgroup') {
    OutputHelper.endGroup(useGroups);
  } else if (level === 'warn') {
    OutputHelper.warn(message);
  } else if (level === 'info') {
    OutputHelper.info(message);
  } else {
    OutputHelper.verbose(message);
  }
}

/** Report through the caller's sink, or straight out when there is none. */
function makeReporter(
  onDiagnostic?: (level: BatchDiagnosticLevel, message: string) => void
): (level: BatchDiagnosticLevel, message: string) => void {
  if (onDiagnostic) {
    return onDiagnostic;
  }

  return (level, message) => emitDiagnostic(level, message, isCI());
}

const BEGIN_MARKER = '===BATCH_TEST_BEGIN ';
const END_MARKER = '===BATCH_TEST_END ';
const SUMMARY_MARKER = '===BATCH_TEST_SUMMARY===';
const MARKER_SUFFIX = '===';

// Matches "<slug> PASS|FAIL [<durationMs>]" — slugs have no whitespace.
const END_INNER_PATTERN = /^(\S+)\s+(?:PASS|FAIL)(?:\s+(\d+))?$/;

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

interface BeginToken {
  kind: 'begin';
  slug: string;
}

interface EndToken {
  kind: 'end';
  slug: string;
  durationMs?: number;
}

interface SummaryToken {
  kind: 'summary';
  /** Where the marker sat, so the JSON payload can be looked up around it. */
  lineIndex: number;
}

interface SummaryPayloadToken {
  kind: 'summaryPayload';
}

interface ContentToken {
  kind: 'content';
  /** The untrimmed line, since section logs are shown to a human verbatim. */
  line: string;
}

/** One log line, classified. Every line becomes exactly one token. */
export type BatchLogToken =
  | BeginToken
  | EndToken
  | SummaryToken
  | SummaryPayloadToken
  | ContentToken;

interface FoldedSections {
  /** Log text of each section that closed, by slug. */
  sections: Map<string, string>;
  /** Sections closed by an END whose BEGIN never arrived — start of output lost. */
  partialSections: Set<string>;
  /** Durations read off END markers, by slug. */
  markerDurations: Map<string, number>;
  /** Slugs of ENDs that closed nothing, so claimed no output. */
  strayEndSlugs: string[];
  /** Slugs of sections a second BEGIN reopened, discarding their output. */
  orphanedBeginSlugs: string[];
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
  const report = makeReporter(options.onDiagnostic);

  // Build reverse map: slug → packageName
  const slugToPackage = new Map<string, string>();
  for (const [packageName, slug] of slugMap) {
    slugToPackage.set(slug, packageName);
  }

  // ── Pass 1: Extract per-package log sections from markers ──

  const tokens = tokenizeBatchLog(lines);
  const {
    sections: logSections,
    partialSections,
    markerDurations,
    strayEndSlugs,
    orphanedBeginSlugs,
  } = foldTokensIntoSections(tokens);

  // Diagnostics are read back off the token list rather than counted alongside
  // the fold, so nothing the warnings report can also steer the parse.
  const beginMarkersSeen = tokensOfKind(tokens, 'begin').length;
  const endMarkersSeen = tokensOfKind(tokens, 'end').length;
  const summaryLineIndex = tokensOfKind(tokens, 'summary')[0]?.lineIndex ?? -1;
  const unknownEndSlugs = [
    ...new Set(
      tokensOfKind(tokens, 'end')
        .map((token) => token.slug)
        .filter((slug) => !slugToPackage.has(slug))
    ),
  ];

  // ── Pass 2: Parse the JSON summary for authoritative pcall results ──

  const summaryResults = new Map<string, boolean>();
  const summaryDurations = new Map<string, number>();
  const summaryErrors = new Map<string, string>();
  const summaryCounts = new Map<string, SummaryCounts>();
  const summaryRanJest = new Map<string, boolean>();
  if (summaryLineIndex >= 0 && summaryLineIndex + 1 < lines.length) {
    const entries = findSummaryEntries(lines, summaryLineIndex + 1);
    if (entries === undefined) {
      report(
        'verbose',
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

  if (strayEndSlugs.length > 0) {
    report(
      'verbose',
      `[batch-log-parser] Ignored ${strayEndSlugs.length} out-of-order END marker(s); ` +
        'their sections closed on their own boundaries.'
    );
  }

  // Reported, not acted on: a slug the batch never asked for means the markers
  // and the package list disagree, which no per-package verdict can express.
  if (unknownEndSlugs.length > 0) {
    report(
      'warn',
      `[batch-log-parser] END marker(s) for slug(s) not in this batch: ` +
        `${unknownEndSlugs.join(', ')}.`
    );
  }

  if (orphanedBeginSlugs.length > 0) {
    report(
      'warn',
      `[batch-log-parser] ${orphanedBeginSlugs.length} section(s) reopened by a ` +
        `second BEGIN before their own END arrived (${orphanedBeginSlugs.join(
          ', '
        )}); ` +
        'the output collected so far was discarded.'
    );
  }

  const noOutputAtAll = logSections.size === 0 && summaryResults.size === 0;
  if (noOutputAtAll) {
    report(
      'warn',
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
    report(
      'warn',
      `[batch-log-parser] Received output but could not attribute any of it to ` +
        `a package section (${logVolume}; ${beginMarkersSeen} BEGIN, ` +
        `${endMarkersSeen} END markers; summary at line ${summaryLineIndex} of ` +
        `${lines.length}). ` +
        'Test counts are not derived from unattributed output.'
    );
    // BEGIN is printed first and the summary last, so their positions separate
    // the two ways this happens: a log window that dropped the head keeps the
    // summary at the end, while reordered messages put it early.
    report(
      'warn',
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
      report(
        'warn',
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
      report(
        'verbose',
        `[batch-log-parser] ${slug}: ignored ${
          tracebacks.length - owned.length
        } traceback(s) belonging to other packages`
      );
    }
    if (owned.length > 0) {
      report(
        'warn',
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
      report(
        'warn',
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
    sectionlessButCounted,
    report,
    results,
    slugMap
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
  sectionlessButCounted: string[],
  report: (level: BatchDiagnosticLevel, message: string) => void,
  results: Map<string, BatchPackageResult>,
  slugMap: Map<string, string>
): void {
  const total = structuredSlugs.length + scrapedSlugs.length;
  if (total === 0) {
    return;
  }

  // Not a failure — this is the case the structured channel was built for — but
  // these packages were judged without their log text, so nothing checked them
  // for tracebacks, which jest cannot count and only the log shows.
  if (sectionlessButCounted.length > 0) {
    report(
      'warn',
      `[batch-log-parser] ${sectionlessButCounted.length} package(s) were judged on ` +
        `their returned counts alone, with no log section to read: ` +
        `${sectionlessButCounted.join(
          ', '
        )}. Their counts are exact; they were ` +
        `not checked for Luau tracebacks, which only the log shows.`
    );
  }

  report(
    'info',
    `[batch-log-parser] Counts returned by the run for ${structuredSlugs.length} ` +
      `of ${total} package(s); ${scrapedSlugs.length} scraped from logs.`
  );

  // Failing every package while every package's counts are clean is a signature,
  // not a coincidence: it means the runner's verdict, not the tests, is wrong.
  if (unexplainedFailures.length > 0) {
    report(
      'warn',
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
    // One group rather than a line per package: the packages differ but the
    // finding does not, and 78 restatements of it buried everything else. The
    // state goes in the title so the group can be left collapsed.
    report(
      'group',
      `${scrapedSlugs.length} of ${total} package(s) fell back to log scraping ` +
        `(no test results returned)`
    );
    report(
      'warn',
      `Counts for these came from log text, the channel Open Cloud truncates on ` +
        `long runs. Their test script should end with "return results" (see ` +
        `docs/testing/testing.md).`
    );
    // Each with its own state: this list is read to find the packages worth
    // looking at, and a column of bare names says nothing about which those are.
    for (const slug of scrapedSlugs) {
      report(
        'info',
        `  ${slug} — ${describeSlugState(slug, results, slugMap)}`
      );
    }
    report('endgroup', '');
  }
}

/**
 * Classify every log line, so section splitting reads tokens instead of text.
 */
export function tokenizeBatchLog(lines: string[]): BatchLogToken[] {
  const tokens: BatchLogToken[] = [];
  /** True between the summary marker and its JSON payload. */
  let summaryPayloadPending = false;

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trimEnd();

    if (trimmed.startsWith(BEGIN_MARKER) && trimmed.endsWith(MARKER_SUFFIX)) {
      tokens.push({
        kind: 'begin',
        slug: trimmed.slice(BEGIN_MARKER.length, -MARKER_SUFFIX.length),
      });
      continue;
    }

    if (trimmed.startsWith(END_MARKER) && trimmed.endsWith(MARKER_SUFFIX)) {
      tokens.push(
        parseEndToken(trimmed.slice(END_MARKER.length, -MARKER_SUFFIX.length))
      );
      continue;
    }

    if (trimmed === SUMMARY_MARKER) {
      // Keep scanning: the summary prints last but is not always delivered last,
      // and a section's END can follow it.
      tokens.push({ kind: 'summary', lineIndex: i });
      summaryPayloadPending = true;
      continue;
    }

    // The summary's JSON payload belongs to no section.
    if (summaryPayloadPending && trimmed.trimStart().startsWith('[')) {
      summaryPayloadPending = false;
      tokens.push({ kind: 'summaryPayload' });
      continue;
    }

    tokens.push({ kind: 'content', line: lines[i] });
  }

  return tokens;
}

/**
 * Read an END marker's inner text.
 *
 * The PASS|FAIL verdict and the duration are both optional, so inner text that
 * does not parse is taken whole as the slug rather than dropped.
 */
function parseEndToken(inner: string): EndToken {
  const match = END_INNER_PATTERN.exec(inner);
  if (!match) {
    return { kind: 'end', slug: inner };
  }

  const durationStr = match[2];
  return {
    kind: 'end',
    slug: match[1],
    durationMs:
      durationStr === undefined ? undefined : parseInt(durationStr, 10),
  };
}

/**
 * Fold tokens into per-package log sections.
 *
 * Sections close on END, not on the next BEGIN, because END is what survives:
 * see the head-claiming rule below.
 */
function foldTokensIntoSections(
  tokens: readonly BatchLogToken[]
): FoldedSections {
  const sections = new Map<string, string>();
  const partialSections = new Set<string>();
  const markerDurations = new Map<string, number>();
  const strayEndSlugs: string[] = [];
  const orphanedBeginSlugs: string[] = [];

  let openSlug: string | null = null;
  let openLines: string[] = [];
  /**
   * Whether the log can still be one whose head was dropped.
   *
   * Open Cloud keeps only the tail of a long run's log, so BEGIN — printed
   * first — can be lost while END and the summary survive. Recovering that
   * means letting an END with no open section claim what precedes it, but
   * only where the head can actually have been dropped: before any BEGIN
   * has survived, and only once. Past that point the log is well-formed,
   * and a BEGIN-less END is a message delivered out of order (the API does
   * not order them), which must not be allowed to claim another package's
   * output.
   */
  let headClaimable = true;

  for (const token of tokens) {
    switch (token.kind) {
      case 'begin': {
        if (openSlug !== null) {
          orphanedBeginSlugs.push(openSlug);
        }
        openSlug = token.slug;
        openLines = [];
        headClaimable = false;
        break;
      }

      case 'end': {
        // A section normally closes on the END matching its own BEGIN.
        const closesOwnSection = token.slug === openSlug;
        // Mutually exclusive with the above: an unclaimed head means no BEGIN
        // has arrived, so no section is open to match.
        const closesDroppedHead = headClaimable;

        if (!closesOwnSection && !closesDroppedHead) {
          // Reordered marker from another package. Ignore it without resetting
          // state, so the section it interrupted still closes on its own END.
          strayEndSlugs.push(token.slug);
          break;
        }

        sections.set(token.slug, openLines.join('\n'));
        if (closesDroppedHead) {
          partialSections.add(token.slug);
        }
        if (token.durationMs !== undefined) {
          markerDurations.set(token.slug, token.durationMs);
        }
        openSlug = null;
        openLines = [];
        headClaimable = false;
        break;
      }

      case 'content': {
        // Accumulate unconditionally: output that precedes the first surviving
        // BEGIN still belongs to whichever package's END closes it.
        openLines.push(token.line);
        break;
      }

      case 'summary':
      case 'summaryPayload': {
        break;
      }
    }
  }

  return {
    sections,
    partialSections,
    markerDurations,
    strayEndSlugs,
    orphanedBeginSlugs,
  };
}

/** Select the tokens of one kind, for counting and reporting. */
function tokensOfKind<K extends BatchLogToken['kind']>(
  tokens: readonly BatchLogToken[],
  kind: K
): Extract<BatchLogToken, { kind: K }>[] {
  return tokens.filter(
    (token): token is Extract<BatchLogToken, { kind: K }> => token.kind === kind
  );
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
