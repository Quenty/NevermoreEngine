import { OutputHelper } from '../outputHelper.js';
import { formatDurationMs } from '../cli-utils.js';
import { BaseReporter, type PackageResult } from './reporter.js';
import { formatTable, type TableColumn } from './format-table.js';
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

    let emptyRunCount = 0;

    const columns: TableColumn<PackageResult>[] = [
      {
        header: 'Package',
        value: (r) => r.packageName,
        minWidth: 40,
      },
      {
        header: 'Status',
        value: (r) => this._statusLabel(r),
        format: (label, r) =>
          this._colorStatus(label, r, () => emptyRunCount++),
        minWidth: 26,
      },
      {
        header: 'Duration',
        value: (r) => formatDurationMs(r.durationMs),
        format: (v) => OutputHelper.formatDim(v),
      },
    ];

    console.log('');
    console.log(formatTable(results, columns));

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

  private _statusLabel(result: PackageResult): string {
    if (result.success) {
      const progressText = formatProgressResult(result.progressSummary);
      return progressText
        ? `${this._successLabel} ${progressText}`
        : this._successLabel;
    }
    const failedPhase = result.failedPhase;
    return failedPhase
      ? `${this._failureLabel} at ${failedPhase}`
      : this._failureLabel;
  }

  private _colorStatus(
    label: string,
    result: PackageResult,
    countEmpty: () => void
  ): string {
    if (result.success) {
      const empty = isEmptyTestRun(result.progressSummary);
      if (empty) countEmpty();
      return empty
        ? OutputHelper.formatWarning(label)
        : OutputHelper.formatSuccess(label);
    }
    return OutputHelper.formatError(label);
  }
}
