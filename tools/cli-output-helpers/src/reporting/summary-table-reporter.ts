import { OutputHelper } from '../outputHelper.js';
import { formatDurationMs } from '../cli-utils.js';
import { BaseReporter } from './reporter.js';
import { type IStateTracker } from './state/state-tracker.js';

/**
 * Prints a final summary table of all results when jobs complete.
 * All output happens in stopAsync().
 */
export class SummaryTableReporter extends BaseReporter {
  private _state: IStateTracker;

  constructor(state: IStateTracker) {
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
