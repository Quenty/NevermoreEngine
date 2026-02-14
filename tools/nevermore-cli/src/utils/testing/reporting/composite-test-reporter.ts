import { type BatchTestResult } from '../runner/batch-test-runner.js';
import { type TestReporter, type TestPhase } from './base-test-reporter.js';
import { LiveTestStateTracker } from './state/live-test-state-tracker.js';

/**
 * Owns a TestRunStateTracker and fans out every lifecycle hook
 * to an array of reporters created by a factory callback.
 *
 * State is always updated first, so reporters see current data.
 */
export class CompositeTestReporter implements TestReporter {
  private _state: LiveTestStateTracker;
  private _reporters: TestReporter[];

  constructor(
    packageNames: string[],
    factory: (state: LiveTestStateTracker) => TestReporter[]
  ) {
    this._state = new LiveTestStateTracker(packageNames);
    this._reporters = factory(this._state);
  }

  async startAsync(): Promise<void> {
    await this._state.startAsync();
    for (const r of this._reporters) {
      await r.startAsync();
    }
  }

  onPackageStart(packageName: string): void {
    this._state.onPackageStart(packageName);
    for (const r of this._reporters) {
      r.onPackageStart(packageName);
    }
  }

  onPackagePhaseChange(packageName: string, phase: TestPhase): void {
    this._state.onPackagePhaseChange(packageName, phase);
    for (const r of this._reporters) {
      r.onPackagePhaseChange(packageName, phase);
    }
  }

  onPackageResult(result: BatchTestResult, bufferedOutput?: string[]): void {
    this._state.onPackageResult(result, bufferedOutput);
    for (const r of this._reporters) {
      r.onPackageResult(result, bufferedOutput);
    }
  }

  async stopAsync(): Promise<void> {
    for (const r of this._reporters) {
      await r.stopAsync();
    }
    await this._state.stopAsync();
  }
}
