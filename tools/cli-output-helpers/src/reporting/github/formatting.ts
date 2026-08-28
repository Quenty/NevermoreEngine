/**
 * Shared types and formatting helpers for GitHub-based reporters.
 *
 * Both the PR comment reporter and job summary reporter use these to
 * render identical markdown tables from batch run state.
 */

import { formatDurationMs } from '../../cli-utils.js';
import {
  type PackageResult,
  type ProgressSummary,
  type JobPhase,
} from '../reporter.js';
import {
  type IStateTracker,
  type PackageState,
} from '../state/state-tracker.js';
import { formatProgressInline } from '../progress-format.js';
import {
  formatStatusText,
  resolveResultStatus,
  statusIcon,
  tallyCaveats,
  type ResultStatus,
} from '../result-status.js';

// ── Public types ────────────────────────────────────────────────────────────

/** A column to render in the GitHub comment table. */
export interface GithubCommentColumn {
  header: string;
  render(pkg: PackageState): string;
  /** 'auto' = hidden when all cells are empty. Default: 'always' */
  visibility?: 'always' | 'auto';
}

/** Configuration for GitHub table reporters. */
export interface GithubCommentTableConfig {
  /** Heading displayed above the table, e.g. "Test Results". */
  heading: string;
  /** HTML comment marker for finding/updating existing comments. */
  commentMarker: string;
  /** Extra columns beyond the built-in Package + Status columns. */
  extraColumns?: GithubCommentColumn[];
  /** Heading for error-only comment (when setError is used). */
  errorHeading?: string;
  /** Label for successful results, e.g. "Deployed". Default: "Passed" */
  successLabel?: string;
  /** Label for failed results, e.g. "Failed". Default: "Failed" */
  failureLabel?: string;
  /** Verb in the footer, e.g. "tested" in "X packages tested, Y passed, Z failed". Default: "tested" */
  summaryVerb?: string;
  /**
   * When true, a successful result that carries no test counts renders as a
   * warning rather than a pass. Set by test reporters: a green check with no
   * counts behind it is indistinguishable from a run that never tested anything.
   */
  expectsTestCounts?: boolean;
  /**
   * When set, the PR comment reporter uses section-based merging.
   * Multiple configs with different sectionIds share a single PR comment,
   * each managing their own section independently.
   */
  sectionId?: string;
}

/** A single row in the rendered GitHub table. */
export interface GithubTableRow {
  packageName: string;
  status: string;
  extraCells: string[];
}

// ── Error summarization ─────────────────────────────────────────────────────

/**
 * Summarize an error string for display in compact contexts (tables, etc.).
 * Parses JSON API error bodies and truncates long messages.
 */
export function summarizeError(error: string, failedPhase?: JobPhase): string {
  const firstLine = error.split('\n')[0];

  // Try to extract JSON error body from API responses
  // Format: "Action failed: STATUS TEXT: {json}"
  const jsonMatch = firstLine.match(/^(.+?failed): (\d{3}) \w+: (.+)$/);
  if (jsonMatch) {
    const [, action, status, jsonBody] = jsonMatch;
    const message = _extractJsonMessage(jsonBody);
    if (message) {
      return `${action} (${status}): ${message}`;
    }
  }

  if (firstLine.length > 80) {
    return firstLine.slice(0, 77) + '...';
  }
  return firstLine;
}

function _extractJsonMessage(text: string): string | undefined {
  try {
    const parsed = JSON.parse(text);
    if (Array.isArray(parsed.errors) && parsed.errors[0]?.message) {
      return parsed.errors[0].message;
    }
    if (typeof parsed.message === 'string') {
      return parsed.message;
    }
  } catch {
    // Not JSON
  }
  return undefined;
}

// ── Table rendering ─────────────────────────────────────────────────────────

// Typed Record<JobPhase, string> so adding a new JobPhase fails the build
// until a label is supplied here.
const RUNNING_PHASE_LABELS: Record<JobPhase, string> = {
  waiting: '⏸ Waiting...',
  building: '🔨 Building...',
  downloading: '⬇ Downloading...',
  merging: '🔀 Merging...',
  combining: '🔗 Combining...',
  uploading: '📤 Uploading...',
  scheduling: '⏳ Scheduling...',
  launching: '🚀 Launching...',
  connecting: '🔌 Connecting...',
  executing: '🔄 Executing...',
};

export function formatRunningStatus(
  phase: JobPhase,
  progress?: ProgressSummary
): string {
  const label = RUNNING_PHASE_LABELS[phase];
  if (progress) {
    const progressText = formatProgressInline(progress);
    return progressText ? `${label} ${progressText}` : label;
  }
  return label;
}

export function formatResultStatus(
  pkg: PackageResult,
  successLabel: string,
  failureLabel: string,
  expectsTestCounts = false
): string {
  const status = resolveResultStatus(pkg, {
    successLabel,
    failureLabel,
    expectsTestCounts,
  });

  // Bolded verdict, plain caveats: a reader scans a column of these for the
  // verdict, and bolding the qualifier too would flatten the difference between
  // them. Everything else — which states exist, what they are called, what
  // counts as a warning — is the resolver's.
  const verdict =
    status.severity === 'failure'
      ? status.failedPhase
        ? `**${status.label}** at ${status.failedPhase}`
        : `**${status.label}**`
      : status.label;
  const caveats = status.caveats.length > 0 ? ` - ${caveatText(status)}` : '';
  const head = [verdict, status.progress].filter(Boolean).join(' ');

  return `${statusIcon(
    status.severity,
    'emoji'
  )} ${head}${caveats} (${formatDurationMs(pkg.durationMs)})`;
}

/** The caveat half of a status line, without the verdict in front of it. */
function caveatText(status: ResultStatus): string {
  return formatStatusText({ ...status, label: '', progress: '' }).replace(
    /^ *- */,
    ''
  );
}

export function getActionsRunUrl(): string | undefined {
  const serverUrl = process.env.GITHUB_SERVER_URL;
  const repository = process.env.GITHUB_REPOSITORY;
  const runId = process.env.GITHUB_RUN_ID;

  if (serverUrl && repository && runId) {
    return `${serverUrl}/${repository}/actions/runs/${runId}`;
  }

  return undefined;
}

/** Render a markdown table with header, data rows, and footer. */
export function formatGithubTable(
  config: GithubCommentTableConfig,
  rows: GithubTableRow[],
  extraColumns: GithubCommentColumn[],
  footer: string
): string {
  // Determine which auto-visibility columns have any content
  const visibleExtras = extraColumns.filter((col) => {
    if (col.visibility === 'auto') {
      return rows.some((r) => {
        const idx = extraColumns.indexOf(col);
        return r.extraCells[idx].length > 0;
      });
    }
    return true;
  });

  const visibleIndices = visibleExtras.map((col) => extraColumns.indexOf(col));
  const actionsRunUrl = getActionsRunUrl();

  let body = config.commentMarker + '\n';
  body += `## ${config.heading}\n\n`;

  // Header row
  const headers = ['Package', 'Status', ...visibleExtras.map((c) => c.header)];
  body += '| ' + headers.join(' | ') + ' |\n';
  body += '|' + headers.map(() => '--------').join('|') + '|\n';

  // Data rows
  for (const row of rows) {
    const cells = [row.packageName, row.status];
    for (const idx of visibleIndices) {
      cells.push(row.extraCells[idx]);
    }
    body += '| ' + cells.join(' | ') + ' |\n';
  }

  body += '\n';
  body += footer;

  if (actionsRunUrl) {
    body += ` · [View logs](${actionsRunUrl})`;
  }

  body += '\n';
  return body;
}

// ── Body composition ────────────────────────────────────────────────────────

function _getAvgDurationMs(state: IStateTracker): number | undefined {
  const results = state.getResults();
  if (results.length === 0) return undefined;
  const totalMs = results.reduce((sum, r) => sum + r.durationMs, 0);
  return totalMs / results.length;
}

function _formatPendingStatus(
  state: IStateTracker,
  concurrency: number,
  queueIndex: number,
  totalPending: number
): string {
  const avgMs = _getAvgDurationMs(state);

  if (avgMs !== undefined) {
    const roundsAhead = Math.floor(queueIndex / concurrency);
    const etaMs = avgMs * (roundsAhead + 1);
    return `⏳ Pending (${
      queueIndex + 1
    }/${totalPending} in ~${formatDurationMs(etaMs)})`;
  }

  return `⏳ Pending (${queueIndex + 1}/${totalPending})`;
}

/**
 * Format the full table body from batch run state.
 * Used by both the PR comment reporter and the job summary reporter.
 */
export function formatGithubTableBody(
  state: IStateTracker,
  config: GithubCommentTableConfig,
  concurrency: number
): string {
  const extraColumns = config.extraColumns ?? [];
  const packages = state.getAllPackages();
  const allDone = packages.every(
    (p) => p.status === 'passed' || p.status === 'failed'
  );
  const elapsedMs = Date.now() - state.startTimeMs;

  let pendingIndex = 0;
  const totalPending = packages.filter((p) => p.status === 'pending').length;

  const rows: GithubTableRow[] = packages.map((pkg: PackageState) => {
    let statusText: string;

    switch (pkg.status) {
      case 'pending':
        statusText = _formatPendingStatus(
          state,
          concurrency,
          pendingIndex++,
          totalPending
        );
        break;
      case 'passed':
      case 'failed':
        statusText = formatResultStatus(
          pkg.result!,
          config.successLabel ?? 'Passed',
          config.failureLabel ?? 'Failed',
          config.expectsTestCounts ?? false
        );
        break;
      default:
        statusText = formatRunningStatus(pkg.status, pkg.progress);
        break;
    }

    const extraCells = extraColumns.map((col) => col.render(pkg));

    return {
      packageName: pkg.name,
      status: statusText,
      extraCells,
    };
  });

  let footer: string;
  if (allDone) {
    const passed = packages.filter((p) => p.status === 'passed').length;
    const failed = packages.filter((p) => p.status === 'failed').length;
    // Tallied off the same statuses the rows were drawn from, so a line here
    // cannot contradict the column above it — which it could when each was
    // counted separately. Read from the final result, not the live progress:
    // progress is cleared once a package resolves.
    const statuses = packages
      .filter((p) => p.result !== undefined)
      .map((p) =>
        resolveResultStatus(p.result!, {
          successLabel: config.successLabel ?? 'Passed',
          failureLabel: config.failureLabel ?? 'Failed',
          expectsTestCounts: config.expectsTestCounts ?? false,
        })
      );
    const verb = config.summaryVerb ?? 'tested';
    const unit = packages.length === 1 ? 'package' : 'packages';
    footer = `**${
      packages.length
    } ${unit} ${verb}, ${passed} passed, ${failed} failed** in ${formatDurationMs(
      elapsedMs
    )}`;
    for (const { message } of tallyCaveats(statuses)) {
      footer += `\n⚠️ ${message}`;
    }
  } else {
    const done = packages.filter(
      (p) => p.status === 'passed' || p.status === 'failed'
    ).length;
    const running = packages.filter(
      (p) =>
        p.status !== 'pending' && p.status !== 'passed' && p.status !== 'failed'
    ).length;
    const pending = packages.filter((p) => p.status === 'pending').length;
    const parts: string[] = [];
    if (done > 0) parts.push(`${done} done`);
    if (running > 0) parts.push(`${running} running`);
    if (pending > 0) parts.push(`${pending} pending`);
    footer = `**${packages.length} packages** · ${parts.join(', ')}`;
  }

  return formatGithubTable(config, rows, extraColumns, footer);
}

/**
 * Format an informational body when no tests were discovered for the run.
 */
export function formatGithubNoTestsBody(
  config: GithubCommentTableConfig,
  message: string
): string {
  const actionsRunUrl = getActionsRunUrl();
  const heading = config.heading;

  const logsPart = actionsRunUrl ? ` · [View logs](${actionsRunUrl})` : '';

  let body = config.commentMarker + '\n';
  body += `## ${heading}\n`;
  body += `ℹ️ ${message}${logsPart}\n`;

  return body;
}

/**
 * Format an error-only body (when the run failed before producing results).
 */
export function formatGithubErrorBody(
  config: GithubCommentTableConfig,
  error: string
): string {
  const actionsRunUrl = getActionsRunUrl();
  const heading = config.errorHeading ?? config.heading;

  let body = config.commentMarker + '\n';
  body += `## ${heading}\n\n`;
  body += `❌ **Run failed before producing results**\n\n`;
  body += `\`\`\`\n${error}\n\`\`\`\n`;

  if (actionsRunUrl) {
    body += `\n[View logs](${actionsRunUrl})\n`;
  }

  return body;
}
