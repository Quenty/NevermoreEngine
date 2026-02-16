import { type PackageResult, type PackageStatus } from '../reporter.js';

export interface PackageState {
  name: string;
  status: PackageStatus;
  startMs?: number;
  durationMs?: number;
  result?: PackageResult;
  bufferedOutput?: string[];
}

/**
 * Read-only interface for batch run state.
 * Both live (LiveStateTracker) and loaded (LoadedStateTracker) implement this.
 */
export interface IStateTracker {
  readonly total: number;
  readonly completed: number;
  readonly startTimeMs: number;
  getPackage(name: string): PackageState | undefined;
  getAllPackages(): PackageState[];
  getResults(): PackageResult[];
  getFailures(): PackageResult[];
}
