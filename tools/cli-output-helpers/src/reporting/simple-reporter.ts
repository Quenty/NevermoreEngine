import { OutputHelper } from '../outputHelper.js';
import { type PackageResult, BaseReporter } from './reporter.js';
import { type IStateTracker } from './state/state-tracker.js';
import { formatProgressResult } from './progress-format.js';

export interface SimpleReporterOptions {
  alwaysShowLogs: boolean;
  /** Message shown on success. Default: "Completed!" */
  successMessage?: string;
  /** Message shown on failure. Default: "Failed!" */
  failureMessage?: string;
}

/**
 * Reporter for single-package execution.
 * Prints logs and pass/fail inline, reads failure state from the tracker.
 */
export class SimpleReporter extends BaseReporter {
  private _state: IStateTracker;
  private _alwaysShowLogs: boolean;
  private _successMessage: string;
  private _failureMessage: string;

  constructor(state: IStateTracker, options: SimpleReporterOptions) {
    super();
    this._state = state;
    this._alwaysShowLogs = options.alwaysShowLogs;
    this._successMessage = options.successMessage ?? 'Completed!';
    this._failureMessage = options.failureMessage ?? 'Failed!';
  }

  override onPackageResult(result: PackageResult): void {
    const showLogs = this._alwaysShowLogs || !result.success;

    if (result.logs && showLogs) {
      console.log(result.logs);
    } else if (showLogs) {
      OutputHelper.info('(no output)');
    }

    const progressText = formatProgressResult(result.progressSummary);
    if (result.success) {
      const msg = progressText ? `${this._successMessage} ${progressText}` : this._successMessage;
      OutputHelper.info(msg);
    } else {
      OutputHelper.error(this._failureMessage);
    }
  }

  override async stopAsync(): Promise<void> {
    if (this._state.getFailures().length > 0) {
      process.exit(1);
    }
  }
}
