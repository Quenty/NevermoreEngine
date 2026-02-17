import * as fs from 'fs/promises';
import { OutputHelper } from '../../outputHelper.js';
import { isCI } from '../../cli-utils.js';
import { BaseReporter } from '../reporter.js';
import { type IStateTracker } from '../state/state-tracker.js';
import {
  type GithubCommentTableConfig,
  formatGithubTableBody,
  formatGithubErrorBody,
  formatGithubNoTestsBody,
} from './formatting.js';

/**
 * Writes batch results to the GitHub Actions job summary.
 *
 * Appends a markdown table to the file at $GITHUB_STEP_SUMMARY, which
 * GitHub renders on the workflow run summary page. Unlike the PR comment
 * reporter, this writes only at completion (no throttled live updates).
 */
export class GithubJobSummaryReporter extends BaseReporter {
  private _state: IStateTracker | undefined;
  private _config: GithubCommentTableConfig;
  private _concurrency: number;
  private _error: string | undefined;
  private _noTestsMessage: string | undefined;

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
   * Set an error message to write instead of results.
   * When set, stopAsync() writes a failure summary rather than a results table.
   */
  setError(error: string): void {
    this._error = error;
  }

  /**
   * Set an informational message when no tests were discovered.
   * When set, stopAsync() writes a neutral summary rather than a results table.
   */
  setNoTestsRun(message: string): void {
    this._noTestsMessage = message;
  }

  override async stopAsync(): Promise<void> {
    if (!_isJobSummaryEnabled()) return;

    let body: string;
    if (this._error) {
      body = formatGithubErrorBody(this._config, this._error);
    } else if (this._noTestsMessage) {
      body = formatGithubNoTestsBody(this._config, this._noTestsMessage);
    } else if (this._state) {
      body = formatGithubTableBody(
        this._state,
        this._config,
        this._concurrency
      );
    } else {
      return;
    }

    const summaryPath = process.env.GITHUB_STEP_SUMMARY!;
    try {
      await fs.appendFile(summaryPath, body);
      OutputHelper.info('Written results to GitHub job summary.');
    } catch (err) {
      OutputHelper.warn(
        `Failed to write job summary: ${err instanceof Error ? err.message : String(err)}`
      );
    }
  }
}

function _isJobSummaryEnabled(): boolean {
  return isCI() && !!process.env.GITHUB_STEP_SUMMARY;
}
