import { type PackageResult, type Reporter, type JobPhase, type ProgressSummary } from './reporter.js';
import { LiveStateTracker } from './state/live-state-tracker.js';

/**
 * Owns a LiveStateTracker and fans out every lifecycle hook
 * to an array of reporters created by a factory callback.
 *
 * State is always updated first, so reporters see current data.
 */
export class CompositeReporter implements Reporter {
  private _state: LiveStateTracker;
  private _reporters: Reporter[];

  constructor(
    packageNames: string[],
    factory: (state: LiveStateTracker) => Reporter[]
  ) {
    this._state = new LiveStateTracker(packageNames);
    this._reporters = factory(this._state);
  }

  get state(): LiveStateTracker {
    return this._state;
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

  onPackagePhaseChange(packageName: string, phase: JobPhase): void {
    this._state.onPackagePhaseChange(packageName, phase);
    for (const r of this._reporters) {
      r.onPackagePhaseChange(packageName, phase);
    }
  }

  onPackageProgressUpdate(packageName: string, progress: ProgressSummary): void {
    this._state.onPackageProgressUpdate(packageName, progress);
    for (const r of this._reporters) {
      r.onPackageProgressUpdate(packageName, progress);
    }
  }

  onPackageResult(result: PackageResult, bufferedOutput?: string[]): void {
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
