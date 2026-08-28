import { OutputHelper } from '../outputHelper.js';
import { formatDurationMs } from '../cli-utils.js';
import { BaseReporter, type PackageResult } from './reporter.js';
import { formatTable, type TableColumn } from './format-table.js';
import { type IStateTracker } from './state/state-tracker.js';
import {
  colorStatus,
  formatStatusText,
  resolveResultStatus,
  tallyCaveats,
  type ResultStatus,
} from './result-status.js';

export interface SummaryTableReporterOptions {
  /** Label for successful results in the table. Default: "Passed" */
  successLabel?: string;
  /** Label for failed results in the table. Default: "FAILED" */
  failureLabel?: string;
  /** Verb in the footer, e.g. "tested" in "X tested, Y passed, Z failed". Default: "tested" */
  summaryVerb?: string;
  /**
   * True when this kind of run should have reported test counts, so a result
   * with none is flagged rather than shown as a plain pass.
   */
  expectsTestCounts?: boolean;
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
  private _expectsTestCounts: boolean;

  constructor(state: IStateTracker, options?: SummaryTableReporterOptions) {
    super();
    this._state = state;
    this._successLabel = options?.successLabel ?? 'Passed';
    this._failureLabel = options?.failureLabel ?? 'FAILED';
    this._summaryVerb = options?.summaryVerb ?? 'tested';
    this._expectsTestCounts = options?.expectsTestCounts ?? false;
  }

  override async stopAsync(): Promise<void> {
    const results = this._state
      .getAllPackages()
      .map((p) => p.result)
      .filter((r): r is PackageResult => r !== undefined);
    if (results.length === 0) return;

    const failures = this._state.getFailures();
    const passed = results.length - failures.length;
    const durationMs = Date.now() - this._state.startTimeMs;

    // Resolved once per result and reused for the row and the footer, so the
    // tally under the table cannot disagree with the rows in it.
    const statuses = new Map<PackageResult, ResultStatus>(
      results.map((result) => [result, this._resolve(result)])
    );

    const columns: TableColumn<PackageResult>[] = [
      {
        header: 'Package',
        value: (r) => r.packageName,
        minWidth: 40,
      },
      {
        header: 'Status',
        value: (r) => formatStatusText(statuses.get(r)!),
        format: (label, r) => colorStatus(label, statuses.get(r)!.severity),
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
    const unit = results.length === 1 ? 'package' : 'packages';
    console.log(
      `${results.length} ${unit} ${this._summaryVerb}, ${passedText}, ${failedText} ${totalTime}`
    );

    for (const { message } of tallyCaveats([...statuses.values()])) {
      console.log(OutputHelper.formatWarning(`⚠ ${message}`));
    }
  }

  private _resolve(result: PackageResult): ResultStatus {
    return resolveResultStatus(result, {
      successLabel: this._successLabel,
      failureLabel: this._failureLabel,
      expectsTestCounts: this._expectsTestCounts,
    });
  }
}
