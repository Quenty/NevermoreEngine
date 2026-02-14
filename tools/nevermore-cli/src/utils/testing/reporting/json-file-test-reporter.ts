import * as fs from 'fs/promises';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { BaseTestReporter } from './base-test-reporter.js';
import { type ITestStateTracker } from './state/test-state-tracker.js';

/**
 * Writes a JSON results file when tests complete.
 * Output matches the BatchTestSummary shape for backward compatibility.
 */
export class JsonFileTestReporter extends BaseTestReporter {
  private _state: ITestStateTracker;
  private _outputPath: string;

  constructor(state: ITestStateTracker, outputPath: string) {
    super();
    this._state = state;
    this._outputPath = outputPath;
  }

  override async stopAsync(): Promise<void> {
    const results = this._state.getResults();
    const failures = this._state.getFailures();
    const durationMs = Date.now() - this._state.startTimeMs;

    const summary = {
      packages: results,
      summary: {
        total: results.length,
        passed: results.length - failures.length,
        failed: failures.length,
        durationMs,
      },
    };

    await fs.writeFile(this._outputPath, JSON.stringify(summary, null, 2));
    OutputHelper.info(`Results written to ${this._outputPath}`);
  }
}
