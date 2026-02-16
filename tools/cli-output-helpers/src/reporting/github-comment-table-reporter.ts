import * as fsSync from 'fs';
import { OutputHelper } from '../outputHelper.js';
import { formatDurationMs, isCI } from '../cli-utils.js';
import {
  type PackageResult,
  type PackageStatus,
  BaseReporter,
} from './reporter.js';
import {
  type IStateTracker,
  type PackageState,
} from './state/state-tracker.js';

// ── Public types ────────────────────────────────────────────────────────────

/** A column to render in the GitHub comment table. */
export interface GithubCommentColumn {
  header: string;
  render(pkg: PackageState): string;
  /** 'auto' = hidden when all cells are empty. Default: 'always' */
  visibility?: 'always' | 'auto';
}

/** Configuration for the GitHub comment table reporter. */
export interface GithubCommentTableConfig {
  /** Heading displayed above the table, e.g. "Test Results". */
  heading: string;
  /** HTML comment marker for finding/updating existing comments. */
  commentMarker: string;
  /** Extra columns beyond the built-in Package + Status columns. */
  extraColumns?: GithubCommentColumn[];
  /** Heading for error-only comment (when setError is used). */
  errorHeading?: string;
}

// ── Error summarization (exported utility) ──────────────────────────────────

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

// ── Comment formatting ──────────────────────────────────────────────────────

interface CommentRow {
  packageName: string;
  status: string;
  extraCells: string[];
}

function _formatComment(
  config: GithubCommentTableConfig,
  rows: CommentRow[],
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
  const actionsRunUrl = _getActionsRunUrl();

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

function _formatResultStatus(pkg: PackageResult): string {
  const duration = formatDurationMs(pkg.durationMs);
  return pkg.success
    ? `✅ Passed (${duration})`
    : `❌ **Failed** (${duration})`;
}

function _getActionsRunUrl(): string | undefined {
  const serverUrl = process.env.GITHUB_SERVER_URL;
  const repository = process.env.GITHUB_REPOSITORY;
  const runId = process.env.GITHUB_RUN_ID;

  if (serverUrl && repository && runId) {
    return `${serverUrl}/${repository}/actions/runs/${runId}`;
  }

  return undefined;
}

// ── GitHub API ──────────────────────────────────────────────────────────────

interface GitHubContext {
  token: string;
  owner: string;
  repo: string;
  prNumber: number;
}

function _resolveGitHubContext(): GitHubContext | undefined {
  const token = process.env.GITHUB_TOKEN;
  const repository = process.env.GITHUB_REPOSITORY;

  if (!token || !repository) {
    return undefined;
  }

  const [owner, repo] = repository.split('/');
  if (!owner || !repo) {
    return undefined;
  }

  let prNumber: number | undefined;

  const refName = process.env.GITHUB_REF_NAME;
  if (refName) {
    const match = refName.match(/^(\d+)\/merge$/);
    if (match) {
      prNumber = parseInt(match[1], 10);
    }
  }

  if (!prNumber) {
    const eventPath = process.env.GITHUB_EVENT_PATH;
    if (eventPath) {
      try {
        const event = JSON.parse(fsSync.readFileSync(eventPath, 'utf-8'));
        prNumber = event?.pull_request?.number ?? event?.number;
      } catch {
        // ignore
      }
    }
  }

  if (!prNumber) {
    return undefined;
  }

  return { token, owner, repo, prNumber };
}

async function _postOrUpdateCommentAsync(
  commentMarker: string,
  body: string
): Promise<boolean> {
  const ctx = _resolveGitHubContext();
  if (!ctx) {
    OutputHelper.warn(
      'GitHub context not available (missing GITHUB_TOKEN, GITHUB_REPOSITORY, or PR number). Skipping PR comment.'
    );
    return false;
  }

  const apiBase = `https://api.github.com/repos/${ctx.owner}/${ctx.repo}`;
  const headers = {
    Authorization: `Bearer ${ctx.token}`,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json',
  };

  const listResponse = await fetch(
    `${apiBase}/issues/${ctx.prNumber}/comments?per_page=100`,
    { headers }
  );

  if (!listResponse.ok) {
    OutputHelper.warn(
      `Failed to list PR comments: ${listResponse.status} ${listResponse.statusText}`
    );
    return false;
  }

  const comments = (await listResponse.json()) as Array<{
    id: number;
    body: string;
  }>;
  const existing = comments.find((c) => c.body.includes(commentMarker));

  if (existing) {
    const updateResponse = await fetch(
      `${apiBase}/issues/comments/${existing.id}`,
      {
        method: 'PATCH',
        headers,
        body: JSON.stringify({ body }),
      }
    );

    if (!updateResponse.ok) {
      OutputHelper.warn(
        `Failed to update PR comment: ${updateResponse.status} ${updateResponse.statusText}`
      );
      return false;
    }

    OutputHelper.info('Updated PR comment with results.');
  } else {
    const createResponse = await fetch(
      `${apiBase}/issues/${ctx.prNumber}/comments`,
      {
        method: 'POST',
        headers,
        body: JSON.stringify({ body }),
      }
    );

    if (!createResponse.ok) {
      OutputHelper.warn(
        `Failed to create PR comment: ${createResponse.status} ${createResponse.statusText}`
      );
      return false;
    }

    OutputHelper.info('Posted PR comment with results.');
  }

  return true;
}

// ── Reporter ────────────────────────────────────────────────────────────────

/**
 * Maintains a live PR comment that updates as jobs progress.
 * The table grid is stable — same rows throughout, only status changes.
 * Updates are throttled to avoid GitHub API rate limits.
 *
 * Also used for post-hoc posting from a LoadedStateTracker (call stopAsync directly).
 */
export class GithubCommentTableReporter extends BaseReporter {
  private _state: IStateTracker | undefined;
  private _config: GithubCommentTableConfig;
  private _concurrency: number;
  private _extraColumns: GithubCommentColumn[];
  private _updateTimer: ReturnType<typeof setTimeout> | undefined;
  private _updatePending = false;
  private _disposed = false;
  private _error: string | undefined;

  private static readonly THROTTLE_MS = 10_000;

  constructor(
    state: IStateTracker | undefined,
    config: GithubCommentTableConfig,
    concurrency?: number
  ) {
    super();
    this._state = state;
    this._config = config;
    this._concurrency = concurrency ?? 1;
    this._extraColumns = config.extraColumns ?? [];
  }

  /**
   * Set an error message to post instead of results.
   * When set, stopAsync() posts a failure comment rather than a results table.
   */
  setError(error: string): void {
    this._error = error;
  }

  override async startAsync(): Promise<void> {
    if (!_isGithubCommentEnabled()) return;
    await this._postUpdateAsync();
  }

  override onPackageStart(_name: string): void {
    this._scheduleUpdate();
  }

  override onPackagePhaseChange(
    _name: string,
    _phase: PackageStatus
  ): void {
    this._scheduleUpdate();
  }

  override onPackageResult(_result: PackageResult): void {
    this._scheduleUpdate();
  }

  override async stopAsync(): Promise<void> {
    this._disposed = true;
    if (this._updateTimer) {
      clearTimeout(this._updateTimer);
      this._updateTimer = undefined;
    }
    if (!_isGithubCommentEnabled()) return;

    if (this._error) {
      await _postOrUpdateCommentAsync(
        this._config.commentMarker,
        this._formatErrorBody()
      );
    } else if (this._state) {
      await this._postUpdateAsync();
    }
  }

  private _scheduleUpdate(): void {
    if (!_isGithubCommentEnabled() || this._disposed) return;
    if (this._updateTimer) {
      this._updatePending = true;
      return;
    }

    this._updateTimer = setTimeout(async () => {
      await this._postUpdateAsync();
      this._updateTimer = undefined;

      if (this._updatePending && !this._disposed) {
        this._updatePending = false;
        this._scheduleUpdate();
      }
    }, GithubCommentTableReporter.THROTTLE_MS);
    this._updateTimer.unref();
  }

  private async _postUpdateAsync(): Promise<void> {
    if (!this._state) return;
    const body = this._formatBody();
    await _postOrUpdateCommentAsync(this._config.commentMarker, body);
  }

  private _formatErrorBody(): string {
    const actionsRunUrl = _getActionsRunUrl();
    const heading = this._config.errorHeading ?? this._config.heading;

    let body = this._config.commentMarker + '\n';
    body += `## ${heading}\n\n`;
    body += `❌ **Run failed before producing results**\n\n`;
    body += `\`\`\`\n${this._error}\n\`\`\`\n`;

    if (actionsRunUrl) {
      body += `\n[View logs](${actionsRunUrl})\n`;
    }

    return body;
  }

  private _getAvgDurationMs(): number | undefined {
    const results = this._state!.getResults();
    if (results.length === 0) return undefined;
    const totalMs = results.reduce((sum, r) => sum + r.durationMs, 0);
    return totalMs / results.length;
  }

  private _formatPendingStatus(
    queueIndex: number,
    totalPending: number
  ): string {
    const avgMs = this._getAvgDurationMs();

    if (avgMs !== undefined) {
      const roundsAhead = Math.floor(queueIndex / this._concurrency);
      const etaMs = avgMs * (roundsAhead + 1);
      return `⏳ Pending (${
        queueIndex + 1
      }/${totalPending} in ~${formatDurationMs(etaMs)})`;
    }

    return `⏳ Pending (${queueIndex + 1}/${totalPending})`;
  }

  private _formatBody(): string {
    const packages = this._state!.getAllPackages();
    const allDone = packages.every(
      (p) => p.status === 'passed' || p.status === 'failed'
    );
    const elapsedMs = Date.now() - this._state!.startTimeMs;

    let pendingIndex = 0;
    const totalPending = packages.filter((p) => p.status === 'pending').length;

    const rows: CommentRow[] = packages.map((pkg: PackageState) => {
      let statusText: string;

      switch (pkg.status) {
        case 'pending':
          statusText = this._formatPendingStatus(pendingIndex++, totalPending);
          break;
        case 'passed':
        case 'failed':
          statusText = _formatResultStatus(pkg.result!);
          break;
        default:
          statusText = _formatRunningStatus(pkg.status);
          break;
      }

      const extraCells = this._extraColumns.map((col) => col.render(pkg));

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
      footer = `**${
        packages.length
      } tested, ${passed} passed, ${failed} failed** in ${formatDurationMs(
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

    return _formatComment(this._config, rows, this._extraColumns, footer);
  }
}

function _isGithubCommentEnabled(): boolean {
  return isCI() && !!process.env.GITHUB_TOKEN;
}

function _formatRunningStatus(phase: PackageStatus): string {
  switch (phase) {
    case 'building':
      return '🔨 Building...';
    case 'uploading':
      return '📤 Uploading...';
    case 'scheduling':
      return '⏳ Scheduling...';
    case 'launching':
      return '🚀 Launching...';
    case 'connecting':
      return '🔌 Connecting...';
    case 'executing':
      return '🔄 Executing...';
    default:
      return '🔄 Running...';
  }
}
