import { OutputHelper } from '@quenty/cli-output-helpers';
import { formatDurationMs } from '../../nevermore-cli-utils.js';
import { BaseTestReporter } from './base-test-reporter.js';
import { type ITestStateTracker } from './state/test-state-tracker.js';

/**
 * Prints a final summary table of all test results when tests complete.
 * All output happens in stopAsync().
 */
export class SummaryTableTestReporter extends BaseTestReporter {
  private _state: ITestStateTracker;

  constructor(state: ITestStateTracker) {
    super();
    this._state = state;
  }

  override async stopAsync(): Promise<void> {
    const results = this._state.getResults();
    if (results.length === 0) return;

    const failures = this._state.getFailures();
    const passed = results.length - failures.length;
    const durationMs = Date.now() - this._state.startTimeMs;

    console.log('');
    console.log('Package'.padEnd(40) + 'Status'.padEnd(10) + 'Duration');
    console.log('-'.repeat(60));

    for (const result of results) {
      const status = result.success
        ? OutputHelper.formatSuccess('Passed')
        : OutputHelper.formatError('FAILED');
      const duration = OutputHelper.formatDim(
        formatDurationMs(result.durationMs)
      );
      console.log(result.packageName.padEnd(40) + status.padEnd(20) + duration);
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
      `${results.length} tested, ${passedText}, ${failedText} ${totalTime}`
    );
  }
}
