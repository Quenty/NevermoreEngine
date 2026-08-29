/**
 * One answer to "how did this turn out", for every place that has to say so.
 *
 * A result's state was worked out independently in four places — the summary
 * table, the grouped reporter, the spinner and the PR comment — and each had its
 * own idea of it. "Ran zero tests" was a warning in three of them and invisible
 * in the fourth; the icon was `⚠` in two and `⚠️` in the others; a pass showed
 * its counts in some and not others; and the run-level tallies at the bottom of
 * each were counted separately, so they could disagree with the rows above them.
 *
 * Adding a fifth state made that untenable: a pass whose log output was dropped
 * is still a pass, but not one that should look like every other green row, and
 * teaching five renderers about it one at a time is how the four drifted in the
 * first place.
 *
 * So state is resolved once, here, and the renderers only choose how to draw it.
 */

import { OutputHelper } from '../outputHelper.js';
import {
  type JobPhase,
  type ProgressSummary,
  type ResultCaveat,
} from './reporter.js';
import { formatProgressResult, isEmptyTestRun } from './progress-format.js';

/** How a result should read at a glance. */
export type ResultSeverity = 'success' | 'warning' | 'failure';

export { type ResultCaveat } from './reporter.js';

interface CaveatCopy {
  /** Short enough to sit in a status line next to the verdict. */
  label: string;
  /** The run-level line, when several results share the caveat. */
  tally: (count: number) => string;
}

const CAVEAT_COPY: Record<ResultCaveat, CaveatCopy> = {
  'no-counts': {
    label: 'no test counts reported',
    tally: (count) =>
      `${count} package(s) reported no test counts — a pass here proves nothing about whether tests ran`,
  },
  'logs-lost': {
    label: 'logs lost',
    tally: (count) =>
      `${count} package(s) lost their log output — their counts came back in the run's summary, but nothing could be checked for tracebacks`,
  },
  'empty-run': {
    label: 'ran 0 tests',
    tally: (count) => `${count} package(s) ran 0 tests — check test discovery`,
  },
};

/**
 * The parts of a result that decide its state.
 *
 * Structural rather than `PackageResult` so a caller holding some other shape —
 * the batch log parser's per-package result, say — can resolve state without
 * first building a reporting type it has no other use for.
 */
export interface ResultStatusInput {
  success: boolean;
  progressSummary?: ProgressSummary;
  failedPhase?: JobPhase;
  /** Per-result override of the reporter's default failure label. */
  failureLabel?: string;
  /**
   * Caveats the producer knows about and the resolver cannot see. `empty-run`
   * and `no-counts` are derived from the counts themselves and need not be
   * passed; `logs-lost` is a fact about the run that only its parser knows.
   */
  caveats?: ResultCaveat[];
}

export interface ResolveResultStatusOptions {
  /** Verdict word for a pass. Default "Passed". */
  successLabel?: string;
  /** Verdict word for a failure. Default "FAILED". */
  failureLabel?: string;
  /**
   * True when this kind of run should have reported test counts, which makes
   * their absence a caveat rather than simply nothing to show.
   */
  expectsTestCounts?: boolean;
}

export interface ResultStatus {
  severity: ResultSeverity;
  /** The verdict word alone: "Passed", "FAILED", "Unverified". */
  label: string;
  /** Where it failed, when the failure names a phase. */
  failedPhase?: JobPhase;
  /** Counts or bytes as "(68/68)", or empty when there are none. */
  progress: string;
  /** Everything qualifying this result, in the order they are worth reading. */
  caveats: ResultCaveat[];
}

/**
 * Work out how a result should be presented.
 *
 * A failure stays a failure whatever its caveats; a pass carrying any caveat
 * becomes a warning. Caveats are not exclusive — a run can report no counts and
 * have lost its logs — so they are collected rather than ranked, and every
 * renderer shows all of them.
 */
export function resolveResultStatus(
  result: ResultStatusInput,
  options: ResolveResultStatusOptions = {}
): ResultStatus {
  const caveats: ResultCaveat[] = [];

  if (
    (options.expectsTestCounts ?? false) &&
    result.progressSummary === undefined
  ) {
    caveats.push('no-counts');
  }
  for (const caveat of result.caveats ?? []) {
    if (!caveats.includes(caveat)) {
      caveats.push(caveat);
    }
  }
  if (isEmptyTestRun(result.progressSummary)) {
    caveats.push('empty-run');
  }

  if (!result.success) {
    return {
      severity: 'failure',
      label: result.failureLabel ?? options.failureLabel ?? 'FAILED',
      failedPhase: result.failedPhase,
      progress: formatProgressResult(result.progressSummary),
      caveats,
    };
  }

  // "Unverified" rather than "Passed": with no counts at all, the run's own
  // account of itself never arrived, and calling that a pass is the claim this
  // is here to avoid making.
  const unverified = caveats.includes('no-counts');

  return {
    severity: caveats.length > 0 ? 'warning' : 'success',
    label: unverified ? 'Unverified' : options.successLabel ?? 'Passed',
    progress: unverified ? '' : formatProgressResult(result.progressSummary),
    caveats,
  };
}

/**
 * The status as one line of plain text: "Passed (35/35) - logs lost".
 *
 * No icon, no duration and no color — those differ between a markdown table, a
 * terminal line and a collapsible group header, and are the renderer's to add.
 */
export function formatStatusText(status: ResultStatus): string {
  const verdict = status.failedPhase
    ? `${status.label} at ${status.failedPhase}`
    : status.label;
  const head = [verdict, status.progress].filter(Boolean).join(' ');
  if (status.caveats.length === 0) {
    return head;
  }

  return `${head} - ${status.caveats
    .map((caveat) => CAVEAT_COPY[caveat].label)
    .join(', ')}`;
}

/**
 * The icon for a severity.
 *
 * `emoji` for markdown, where they render as intended; `ascii` for a terminal
 * line, where a variation-selector emoji is two columns wide and breaks column
 * alignment.
 */
export function statusIcon(
  severity: ResultSeverity,
  style: 'emoji' | 'ascii'
): string {
  if (style === 'emoji') {
    return severity === 'failure' ? '❌' : severity === 'warning' ? '⚠️' : '✅';
  }

  return severity === 'failure' ? '✗' : severity === 'warning' ? '⚠' : '✓';
}

/** Color text by severity, using the shared palette. */
export function colorStatus(text: string, severity: ResultSeverity): string {
  if (severity === 'failure') {
    return OutputHelper.formatError(text);
  }
  if (severity === 'warning') {
    return OutputHelper.formatWarning(text);
  }

  return OutputHelper.formatSuccess(text);
}

/**
 * Roll up the caveats across a run, for the lines under a summary.
 *
 * Counted off the same statuses the rows were drawn from, so the tally and the
 * rows cannot disagree — which they could when each reporter counted its own.
 */
export function tallyCaveats(
  statuses: ResultStatus[]
): Array<{ caveat: ResultCaveat; count: number; message: string }> {
  const counts = new Map<ResultCaveat, number>();
  for (const status of statuses) {
    for (const caveat of status.caveats) {
      counts.set(caveat, (counts.get(caveat) ?? 0) + 1);
    }
  }

  const order: ResultCaveat[] = ['no-counts', 'logs-lost', 'empty-run'];

  return order
    .filter((caveat) => counts.has(caveat))
    .map((caveat) => {
      const count = counts.get(caveat)!;
      return { caveat, count, message: CAVEAT_COPY[caveat].tally(count) };
    });
}
