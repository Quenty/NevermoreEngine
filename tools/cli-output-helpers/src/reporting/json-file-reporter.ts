import * as fs from 'fs/promises';
import { OutputHelper } from '../outputHelper.js';
import { BaseReporter } from './reporter.js';
import { type IStateTracker } from './state/state-tracker.js';

/**
 * Writes a JSON results file when jobs complete.
 * Output matches the BatchSummary shape for backward compatibility.
 */
export class JsonFileReporter extends BaseReporter {
  private _state: IStateTracker;
  private _outputPath: string;

  constructor(state: IStateTracker, outputPath: string) {
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
