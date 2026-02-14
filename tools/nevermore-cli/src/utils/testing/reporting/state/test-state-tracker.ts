import { type BatchTestResult } from '../../runner/batch-test-runner.js';
import { type PackageTestStatus } from '../base-test-reporter.js';

export interface PackageState {
  name: string;
  status: PackageTestStatus;
  startMs?: number;
  durationMs?: number;
  result?: BatchTestResult;
  bufferedOutput?: string[];
}

/**
 * Read-only interface for test run state.
 * Both live (LiveTestStateTracker) and loaded (LoadedTestStateTracker) implement this.
 */
export interface ITestStateTracker {
  readonly total: number;
  readonly completed: number;
  readonly startTimeMs: number;
  getPackage(name: string): PackageState | undefined;
  getAllPackages(): PackageState[];
  getResults(): BatchTestResult[];
  getFailures(): BatchTestResult[];
}
