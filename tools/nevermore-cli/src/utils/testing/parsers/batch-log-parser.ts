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
const MARKER_SUFFIX = '===';

// Matches "<slug> PASS|FAIL [<durationMs>]" — slugs have no whitespace.
const END_INNER_PATTERN = /^(\S+)\s+(?:PASS|FAIL)(?:\s+(\d+))?$/;

interface SummaryEntry {
  slug: string;
  success: boolean;
  durationMs?: number;
  error?: string;
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
type BatchLogToken =
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
      }
      // Log any pcall failures from the Luau template
      const failures = entries.filter((e) => !e.success);
      if (failures.length > 0) {
        console.error(
          `[batch-log-parser] Luau pcall failures: ${JSON.stringify(failures)}`
        );
      }
      console.error(
        `[batch-log-parser] Parsed ${entries.length} summary entries, ${failures.length} pcall failures`
      );
    }
  }

  // ── Warn when the batch produced no recognizable output ──

  if (strayEndSlugs.length > 0) {
    OutputHelper.verbose(
      `[batch-log-parser] Ignored ${strayEndSlugs.length} out-of-order END marker(s); ` +
        'their sections closed on their own boundaries.'
    );
  }

  // Reported, not acted on: a slug the batch never asked for means the markers
  // and the package list disagree, which no per-package verdict can express.
  if (unknownEndSlugs.length > 0) {
    OutputHelper.warn(
      `[batch-log-parser] END marker(s) for slug(s) not in this batch: ` +
        `${unknownEndSlugs.join(', ')}.`
    );
  }

  if (orphanedBeginSlugs.length > 0) {
    OutputHelper.warn(
      `[batch-log-parser] ${orphanedBeginSlugs.length} section(s) reopened by a ` +
        `second BEGIN before their own END arrived (${orphanedBeginSlugs.join(
          ', '
        )}); ` +
        'the output collected so far was discarded.'
    );
  }

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
    if (summarySuccess === false) {
      reasons.push('the batch runner reported a Luau error');
    } else if (summarySuccess === undefined) {
      // Absent from the summary is a different fault from failing in it, and
      // conflating them sends you hunting for a Luau error that never happened.
      reasons.push('this package is missing from the batch summary');
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

/**
 * Classify every log line, so section splitting reads tokens instead of text.
 */
function tokenizeBatchLog(lines: string[]): BatchLogToken[] {
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
