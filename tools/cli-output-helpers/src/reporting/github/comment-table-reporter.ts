import * as fsSync from 'fs';
import { OutputHelper } from '../../outputHelper.js';
import { isCI } from '../../cli-utils.js';
import {
  type PackageResult,
  type PackageStatus,
  BaseReporter,
} from '../reporter.js';
import { type IStateTracker } from '../state/state-tracker.js';
import {
  type GithubCommentTableConfig,
  formatGithubTableBody,
  formatGithubErrorBody,
  formatGithubNoTestsBody,
} from './formatting.js';

// Re-export types that were originally defined in this module
export type {
  GithubCommentColumn,
  GithubCommentTableConfig,
  GithubTableRow,
} from './formatting.js';
export { summarizeError } from './formatting.js';

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
  private _updateTimer: ReturnType<typeof setTimeout> | undefined;
  private _updatePending = false;
  private _disposed = false;
  private _error: string | undefined;
  private _noTestsMessage: string | undefined;

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
  }

  /**
   * Set an error message to post instead of results.
   * When set, stopAsync() posts a failure comment rather than a results table.
   */
  setError(error: string): void {
    this._error = error;
  }

  /**
   * Set an informational message when no tests were discovered.
   * When set, stopAsync() posts a neutral comment rather than a results table.
   */
  setNoTestsRun(message: string): void {
    this._noTestsMessage = message;
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
        formatGithubErrorBody(this._config, this._error)
      );
    } else if (this._noTestsMessage) {
      await _postOrUpdateCommentAsync(
        this._config.commentMarker,
        formatGithubNoTestsBody(this._config, this._noTestsMessage)
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
    const body = formatGithubTableBody(
      this._state,
      this._config,
      this._concurrency
    );
    await _postOrUpdateCommentAsync(this._config.commentMarker, body);
  }
}

function _isGithubCommentEnabled(): boolean {
  return isCI() && !!process.env.GITHUB_TOKEN;
}
