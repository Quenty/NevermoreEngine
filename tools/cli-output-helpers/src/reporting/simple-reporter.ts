import { OutputHelper } from '../outputHelper.js';
import {
  type JobPhase,
  type PackageResult,
  type ProgressSummary,
  BaseReporter,
} from './reporter.js';
import { type IStateTracker } from './state/state-tracker.js';
import { formatProgressInline, formatProgressResult } from './progress-format.js';

export interface SimpleReporterOptions {
  alwaysShowLogs: boolean;
  /**
   * When true, every package lifecycle event prints a `[name] status` line.
   * Default false — only the final result is printed.
   */
  verbose?: boolean;
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
  private _verbose: boolean;
  private _successMessage: string;
  private _failureMessage: string;
  private _lastVerboseLine: string | undefined;

  constructor(state: IStateTracker, options: SimpleReporterOptions) {
    super();
    this._state = state;
    this._alwaysShowLogs = options.alwaysShowLogs;
    this._verbose = options.verbose ?? false;
    this._successMessage = options.successMessage ?? 'Completed!';
    this._failureMessage = options.failureMessage ?? 'Failed!';
  }

  override onPackageStart(name: string): void {
    this._logVerbose(name, 'started');
  }

  override onPackagePhaseChange(name: string, phase: JobPhase): void {
    this._logVerbose(name, phase);
  }

  override onPackageProgressUpdate(
    name: string,
    progress: ProgressSummary
  ): void {
    // Strip the surrounding parens formatProgressInline adds for spinner use.
    const status = formatProgressInline(progress).replace(/^\(|\)$/g, '');
    if (!status) return;

    // Prefix with the active phase so progress lines read as
    // "[pkg] uploading 1.2 MB/2.0 MB" instead of just "[pkg] 1.2 MB/2.0 MB".
    const phase = this._state.getCurrentPhase(name);
    const labeled =
      phase && phase !== 'pending' && phase !== 'passed' && phase !== 'failed'
        ? `${phase} ${status}`
        : status;
    this._logVerbose(name, labeled);
  }

  // Dedupes consecutive identical lines so high-frequency byte/poll updates
  // that happen to render to the same string don't spam.
  private _logVerbose(name: string, status: string): void {
    if (!this._verbose) return;
    const line = `[${name}] ${status}`;
    if (line === this._lastVerboseLine) return;
    this._lastVerboseLine = line;
    OutputHelper.info(line);
  }

  override onPackageResult(result: PackageResult): void {
    const showLogs = this._alwaysShowLogs || !result.success;

    if (result.logs && showLogs) {
      console.log(result.logs);
    } else if (showLogs && !result.error) {
      OutputHelper.info('(no output)');
    }

    if (result.error) {
      OutputHelper.error(result.error);
    }

    const progressText = formatProgressResult(result.progressSummary);
    if (result.success) {
      const msg = progressText
        ? `${this._successMessage} ${progressText}`
        : this._successMessage;
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
