import { OutputHelper } from '@quenty/cli-output-helpers';
import { type BatchTestResult } from './base-test-reporter.js';
import { BaseTestReporter } from './base-test-reporter.js';
import { type ITestStateTracker } from './state/test-state-tracker.js';

/**
 * Reporter for single-package test execution.
 * Prints logs and pass/fail inline, reads failure state from the tracker.
 */
export class SimpleTestReporter extends BaseTestReporter {
  private _state: ITestStateTracker;
  private _alwaysShowLogs: boolean;

  constructor(state: ITestStateTracker, options: { alwaysShowLogs: boolean }) {
    super();
    this._state = state;
    this._alwaysShowLogs = options.alwaysShowLogs;
  }

  override onPackageResult(result: BatchTestResult): void {
    const showLogs = this._alwaysShowLogs || !result.success;

    if (result.logs && showLogs) {
      console.log(result.logs);
    } else if (showLogs) {
      OutputHelper.info('(no output)');
    }

    if (result.success) {
      OutputHelper.info('Tests passed!');
    } else {
      OutputHelper.error(
        'Tests failed! See output above for more information.'
      );
    }
  }

  override async stopAsync(): Promise<void> {
    if (this._state.getFailures().length > 0) {
      process.exit(1);
    }
  }
}
