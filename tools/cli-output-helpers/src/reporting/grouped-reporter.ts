import { OutputHelper } from '../outputHelper.js';
import { formatDurationMs, isCI } from '../cli-utils.js';
import { type PackageResult, BaseReporter } from './reporter.js';
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
  /**
   * When true, this reporter says nothing per package, because something else
   * already printed the run.
   *
   * Set by an aggregated batch. One task runs every package, so there is no
   * per-package moment to report: every package starts in the same tick before
   * the task exists, which made the groups open back-to-back around no output,
   * and the batch-wide progress lines land in whichever package's async
   * context first triggered the shared promise — the upload and the build list
   * were being filed under two arbitrary packages. The run's own renderer
   * shows each section with its verdict in the title, and the summary table
   * recaps at the end, so a header and a repeated verdict here is noise:
   * 78 packages meant 78 such blocks.
   */
  logsRenderedElsewhere?: boolean;
}

/**
 * CI / verbose / non-TTY output for batch job progress.
 * Prints grouped result blocks as each package completes.
 */
export class GroupedReporter extends BaseReporter {
  private _state: IStateTracker;
  private _options: GroupedReporterOptions;
  private _isCI: boolean;

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
    if (this._isCI && !this._options.logsRenderedElsewhere) {
      console.log(`::group::${name}`);
    }
  }

  override onPackageResult(
    result: PackageResult,
    bufferedOutput?: string[]
  ): void {
    if (this._options.logsRenderedElsewhere) {
      return;
    }

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

    const showLogs =
      (this._options.showLogs || !result.success) &&
      !this._options.logsRenderedElsewhere;
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

    if (this._isCI && !this._options.logsRenderedElsewhere) {
      console.log('::endgroup::');
    }

    console.log('');
  }
}
