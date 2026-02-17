/**
 * Shared types and formatting helpers for GitHub-based reporters.
 *
 * Both the PR comment reporter and job summary reporter use these to
 * render identical markdown tables from batch run state.
 */

import { formatDurationMs } from '../../cli-utils.js';
import {
  type PackageResult,
  type PackageStatus,
} from '../reporter.js';
import {
  type IStateTracker,
  type PackageState,
} from '../state/state-tracker.js';

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
  /** Verb in the footer, e.g. "tested" in "X tested, Y passed, Z failed". Default: "tested" */
  summaryVerb?: string;
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
export function summarizeError(error: string): string {
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

const RUNNING_PHASE_LABELS: Record<string, string> = {
  building: '🔨 Building...',
  uploading: '📤 Uploading...',
  scheduling: '⏳ Scheduling...',
  launching: '🚀 Launching...',
  connecting: '🔌 Connecting...',
  executing: '🔄 Executing...',
};

export function formatRunningStatus(phase: PackageStatus): string {
  return RUNNING_PHASE_LABELS[phase] ?? '🔄 Running...';
}

export function formatResultStatus(
  pkg: PackageResult,
  successLabel: string,
  failureLabel: string
): string {
  const duration = formatDurationMs(pkg.durationMs);
  return pkg.success
    ? `✅ ${successLabel} (${duration})`
    : `❌ **${failureLabel}** (${duration})`;
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
          config.failureLabel ?? 'Failed'
        );
        break;
      default:
        statusText = formatRunningStatus(pkg.status);
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
    const verb = config.summaryVerb ?? 'tested';
    footer = `**${
      packages.length
    } ${verb}, ${passed} passed, ${failed} failed** in ${formatDurationMs(
      elapsedMs
    )}`;
  } else {
    const done = packages.filter(
      (p) => p.status === 'passed' || p.status === 'failed'
    ).length;
    const running = packages.filter(
      (p) =>
        p.status !== 'pending' &&
        p.status !== 'passed' &&
        p.status !== 'failed'
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

  let body = config.commentMarker + '\n';
  body += `## ${heading}\n\n`;
  body += `ℹ️ **No tests to run**\n\n`;
  body += `${message}\n`;

  if (actionsRunUrl) {
    body += `\n[View logs](${actionsRunUrl})\n`;
  }

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
