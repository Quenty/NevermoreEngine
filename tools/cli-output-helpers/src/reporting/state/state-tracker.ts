import { type PackageResult, type PackageStatus, type ProgressSummary } from '../reporter.js';

export interface PackageState {
  name: string;
  status: PackageStatus;
  startMs?: number;
  durationMs?: number;
  result?: PackageResult;
  bufferedOutput?: string[];
  progress?: ProgressSummary;
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
  getCurrentPhase(name: string): PackageStatus | undefined;
}
