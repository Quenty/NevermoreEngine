import { OutputHelper } from '../outputHelper.js';
import { formatDurationMs } from '../cli-utils.js';
import { BaseReporter } from './reporter.js';
import { type IStateTracker } from './state/state-tracker.js';
import { formatProgressResult, isEmptyTestRun } from './progress-format.js';

export interface SummaryTableReporterOptions {
  /** Label for successful results in the table. Default: "Passed" */
  successLabel?: string;
  /** Label for failed results in the table. Default: "FAILED" */
  failureLabel?: string;
  /** Verb in the footer, e.g. "tested" in "X tested, Y passed, Z failed". Default: "tested" */
  summaryVerb?: string;
}

/**
 * Prints a final summary table of all results when jobs complete.
 * All output happens in stopAsync().
 */
export class SummaryTableReporter extends BaseReporter {
  private _state: IStateTracker;
  private _successLabel: string;
  private _failureLabel: string;
  private _summaryVerb: string;

  constructor(state: IStateTracker, options?: SummaryTableReporterOptions) {
    super();
    this._state = state;
    this._successLabel = options?.successLabel ?? 'Passed';
    this._failureLabel = options?.failureLabel ?? 'FAILED';
    this._summaryVerb = options?.summaryVerb ?? 'tested';
  }

  override async stopAsync(): Promise<void> {
    const results = this._state.getResults();
    if (results.length === 0) return;

    const failures = this._state.getFailures();
    const passed = results.length - failures.length;
    const durationMs = Date.now() - this._state.startTimeMs;

    const STATUS_WIDTH = 26;

    console.log('');
    console.log('Package'.padEnd(40) + 'Status'.padEnd(STATUS_WIDTH) + 'Duration');
    console.log('─'.repeat(40 + STATUS_WIDTH + 8));

    let emptyRunCount = 0;
    for (const result of results) {
      const progressText = formatProgressResult(result.progressSummary);
      const empty = isEmptyTestRun(result.progressSummary);
      if (empty) emptyRunCount++;

      let label: string;
      if (result.success) {
        label = progressText ? `${this._successLabel} ${progressText}` : this._successLabel;
      } else {
        const failedPhase = result.failedPhase;
        label = failedPhase
          ? `${this._failureLabel} at ${failedPhase}`
          : this._failureLabel;
      }

      // Pad the plain text BEFORE wrapping in ANSI so padEnd counts visible chars
      const paddedLabel = label.padEnd(STATUS_WIDTH);
      let status: string;
      if (result.success) {
        status = empty
          ? OutputHelper.formatWarning(paddedLabel)
          : OutputHelper.formatSuccess(paddedLabel);
      } else {
        status = OutputHelper.formatError(paddedLabel);
      }

      const duration = OutputHelper.formatDim(
        formatDurationMs(result.durationMs)
      );
      console.log(result.packageName.padEnd(40) + status + duration);
    }

    console.log('');
    const passedText = OutputHelper.formatSuccess(`${passed} passed`);
    const failedText =
      failures.length > 0
        ? OutputHelper.formatError(`${failures.length} failed`)
        : `${failures.length} failed`;
    const totalTime = OutputHelper.formatDim(
      `in ${formatDurationMs(durationMs)}`
    );
    console.log(
      `${results.length} ${this._summaryVerb}, ${passedText}, ${failedText} ${totalTime}`
    );

    if (emptyRunCount > 0) {
      console.log(
        OutputHelper.formatWarning(
          `⚠ ${emptyRunCount} package(s) ran 0 tests — check test discovery`
        )
      );
    }
  }
}
