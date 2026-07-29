import { OutputHelper } from '../outputHelper.js';
import { formatDurationMs, isCI } from '../cli-utils.js';
import { type JobPhase, type PackageResult, BaseReporter } from './reporter.js';
import { type IStateTracker } from './state/state-tracker.js';
import {
  formatProgressResult,
  isEmptyTestRun,
  isUnreportedTestRun,
} from './progress-format.js';

export interface GroupedReporterOptions {
  showLogs: boolean;
  verbose: boolean;
  /** Verb used in the header, e.g. "Testing", "Deploying". Default: "Processing" */
  actionVerb?: string;
  /** Label for successful results, e.g. "Deployed". Default: "Passed" */
  successLabel?: string;
  /** Label for failed results, e.g. "DEPLOY FAILED". Default: "FAILED" */
  failureLabel?: string;
  /**
   * When true, a success carrying no test counts prints as unverified. Set by
   * test runs: a ✓ with no numbers behind it looks identical to a real pass.
   */
  expectsTestCounts?: boolean;
}

/**
 * CI / verbose / non-TTY output for batch job progress.
 * Prints grouped result blocks as each package completes.
 */
export class GroupedReporter extends BaseReporter {
  private _state: IStateTracker;
  private _options: GroupedReporterOptions;
  private _isCI: boolean;
  private _phaseStartedMs = Date.now();
  private _lastPhase?: JobPhase;

  constructor(state: IStateTracker, options: GroupedReporterOptions) {
    super();
    this._state = state;
    this._options = options;
    this._isCI = isCI();
  }

  override async startAsync(): Promise<void> {
    const verb = this._options.actionVerb ?? 'Processing';
    OutputHelper.info(`${verb} ${this._state.total} packages`);
  }

  override onPackageStart(name: string): void {
    if (this._isCI) {
      console.log(`::group::${name}`);
    }
    this._phaseStartedMs = Date.now();
    this._lastPhase = undefined;
  }

  override onPackagePhaseChange(name: string, phase: JobPhase): void {
    if (!this._options.verbose) {
      return;
    }

    // Group output is buffered and flushed at the end, so every line lands on
    // the same timestamp and a five-minute step reads as instantaneous. Print
    // how long the phase it just left actually took.
    const now = Date.now();
    if (this._lastPhase !== undefined) {
      const elapsed = formatDurationMs(now - this._phaseStartedMs);
      OutputHelper.info(`  [${name}] ${this._lastPhase} took ${elapsed}`);
    }
    this._lastPhase = phase;
    this._phaseStartedMs = now;
  }

  override onPackageResult(
    result: PackageResult,
    bufferedOutput?: string[]
  ): void {
    this._printGroupedResult(result, bufferedOutput);
  }

  private _printGroupedResult(
    result: PackageResult,
    bufferedOutput?: string[]
  ): void {
    const headerWidth = 50;
    const label = ` ${result.packageName} `;
    const dashCount = Math.max(0, headerWidth - label.length);
    const leftDash = '─'.repeat(Math.floor(dashCount / 2));
    const rightDash = '─'.repeat(Math.ceil(dashCount / 2));
    const header = `${leftDash}${label}${rightDash}`;

    console.log(OutputHelper.formatDim(header));

    if (bufferedOutput && bufferedOutput.length > 0) {
      for (const line of bufferedOutput) {
        console.log(`  ${line}`);
      }
    }

    const showLogs = this._options.showLogs || !result.success;
    const duration = formatDurationMs(result.durationMs);
    const successLabel = this._options.successLabel ?? 'Passed';
    const failureLabel =
      result.failureLabel ?? this._options.failureLabel ?? 'FAILED';

    const progressText = formatProgressResult(result.progressSummary);
    const empty = isEmptyTestRun(result.progressSummary);

    const unverified =
      (this._options.expectsTestCounts ?? false) &&
      isUnreportedTestRun(result.progressSummary);

    if (result.success) {
      const label = unverified
        ? 'Unverified — no test counts reported'
        : progressText
        ? `${successLabel} ${progressText}`
        : successLabel;
      const formatted =
        empty || unverified
          ? OutputHelper.formatWarning(`${label} ⚠`)
          : OutputHelper.formatSuccess(label);
      const icon =
        empty || unverified
          ? OutputHelper.formatWarning('⚠')
          : OutputHelper.formatSuccess('✓');
      console.log(
        `  ${icon} ${formatted} ${OutputHelper.formatDim(`(${duration})`)}`
      );
    } else {
      const failedPhase = result.failedPhase;
      const label = failedPhase
        ? `${failureLabel} at ${failedPhase}`
        : failureLabel;
      console.log(
        `  ${OutputHelper.formatError('✗')} ${OutputHelper.formatError(
          label
        )} ${OutputHelper.formatDim(`(${duration})`)}`
      );
    }

    if (showLogs) {
      if (result.logs) {
        // jest-lua's escape codes reach here as log content, past chalk.
        console.log(
          process.env.NO_COLOR
            ? OutputHelper.stripAnsi(result.logs)
            : result.logs
        );
      } else {
        // Says only what is known: this package has no logs attached. Whether
        // the run produced none, or produced some that could not be attributed,
        // is the parser's to report — claiming either here would be a guess.
        console.log(
          OutputHelper.formatWarning('  (no logs attached to this package)')
        );
      }
      if (result.error) {
        console.log(`  ${OutputHelper.formatError(result.error)}`);
      }
    }

    if (this._isCI) {
      console.log('::endgroup::');
    }

    console.log('');
  }
}
