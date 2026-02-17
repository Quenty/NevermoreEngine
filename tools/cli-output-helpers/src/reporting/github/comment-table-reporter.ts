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
import { postOrUpdateCommentAsync } from './github-api.js';

// Re-export types that were originally defined in this module
export type {
  GithubCommentColumn,
  GithubCommentTableConfig,
  GithubTableRow,
} from './formatting.js';
export { summarizeError } from './formatting.js';

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
      await this._postCommentAsync(
        formatGithubErrorBody(this._config, this._error)
      );
    } else if (this._noTestsMessage) {
      await this._postCommentAsync(
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
    await this._postCommentAsync(body);
  }

  private async _postCommentAsync(body: string): Promise<void> {
    await postOrUpdateCommentAsync(this._config.commentMarker, body);
  }
}

function _isGithubCommentEnabled(): boolean {
  return isCI() && !!process.env.GITHUB_TOKEN;
}
