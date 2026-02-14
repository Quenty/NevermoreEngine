import { OutputHelper } from '@quenty/cli-output-helpers';
import { type BatchTestResult } from '../runner/batch-test-runner.js';
import { formatDurationMs, isCI } from '../../nevermore-cli-utils.js';
import { BaseTestReporter } from './base-test-reporter.js';
import { type ITestStateTracker } from './state/test-state-tracker.js';

export interface GroupedTestReporterOptions {
  showLogs: boolean;
  verbose: boolean;
}

/**
 * CI / verbose / non-TTY output for batch test progress.
 * Prints grouped result blocks as each package completes.
 */
export class GroupedTestReporter extends BaseTestReporter {
  private _state: ITestStateTracker;
  private _options: GroupedTestReporterOptions;
  private _isCI: boolean;

  constructor(state: ITestStateTracker, options: GroupedTestReporterOptions) {
    super();
    this._state = state;
    this._options = options;
    this._isCI = isCI();
  }

  override async startAsync(): Promise<void> {
    OutputHelper.info(`Testing ${this._state.total} packages`);
  }

  override onPackageStart(name: string): void {
    if (this._isCI) {
      console.log(`::group::${name}`);
    }
  }

  override onPackageResult(
    result: BatchTestResult,
    bufferedOutput?: string[]
  ): void {
    this._printGroupedResult(result, bufferedOutput);
  }

  private _printGroupedResult(
    result: BatchTestResult,
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
    if (result.success) {
      console.log(
        `  ${OutputHelper.formatSuccess('✓')} ${OutputHelper.formatSuccess(
          'Passed'
        )} ${OutputHelper.formatDim(`(${duration})`)}`
      );
    } else {
      console.log(
        `  ${OutputHelper.formatError('✗')} ${OutputHelper.formatError(
          'FAILED'
        )} ${OutputHelper.formatDim(`(${duration})`)}`
      );
    }

    if (showLogs) {
      if (result.logs) {
        console.log(result.logs);
      } else {
        console.log(OutputHelper.formatDim('  (no output)'));
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
