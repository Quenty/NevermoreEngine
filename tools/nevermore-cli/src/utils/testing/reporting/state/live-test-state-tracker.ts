import { type BatchTestResult } from '../../runner/batch-test-runner.js';
import { BaseTestReporter, type TestPhase } from '../base-test-reporter.js';
import {
  type ITestStateTracker,
  type PackageState,
} from './test-state-tracker.js';

export type { PackageState } from './test-state-tracker.js';

/**
 * Centralized state container for a live test run.
 * Extends BaseTestReporter to receive lifecycle hooks and mutate state.
 * Reporters read from it via the TestStateReader interface.
 */
export class LiveTestStateTracker
  extends BaseTestReporter
  implements ITestStateTracker
{
  private _packages: Map<string, PackageState>;
  private _startTimeMs = 0;
  private _completed = 0;
  private _failures: BatchTestResult[] = [];
  private _allResults: BatchTestResult[] = [];

  constructor(packageNames: string[]) {
    super();
    this._packages = new Map();
    for (const name of packageNames) {
      this._packages.set(name, { name, status: 'pending' });
    }
  }

  get total(): number {
    return this._packages.size;
  }

  get completed(): number {
    return this._completed;
  }

  get startTimeMs(): number {
    return this._startTimeMs;
  }

  getPackage(name: string): PackageState | undefined {
    return this._packages.get(name);
  }

  getAllPackages(): PackageState[] {
    return [...this._packages.values()];
  }

  getResults(): BatchTestResult[] {
    return this._allResults;
  }

  getFailures(): BatchTestResult[] {
    return this._failures;
  }

  override async startAsync(): Promise<void> {
    this._startTimeMs = Date.now();
  }

  override onPackageStart(name: string): void {
    const state = this._packages.get(name);
    if (!state) return;
    state.status = 'building';
    state.startMs = Date.now();
  }

  override onPackagePhaseChange(name: string, phase: TestPhase): void {
    const state = this._packages.get(name);
    if (!state) return;
    state.status = phase;
  }

  override onPackageResult(
    result: BatchTestResult,
    bufferedOutput?: string[]
  ): void {
    const state = this._packages.get(result.packageName);
    if (!state) return;

    state.status = result.success ? 'passed' : 'failed';
    state.durationMs = result.durationMs;
    state.result = result;
    state.bufferedOutput = bufferedOutput;
    this._completed++;

    this._allResults.push(result);
    if (!result.success) {
      this._failures.push(result);
    }
  }
}
