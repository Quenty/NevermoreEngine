import * as fs from 'fs/promises';
import {
  type PackageResult,
  type PackageStatus,
  type BatchSummary,
} from '../reporter.js';
import {
  type IStateTracker,
  type PackageState,
} from './state-tracker.js';

/**
 * Batch state loaded from a previously-saved BatchSummary JSON file.
 * All packages are already in their final passed/failed state.
 */
export class LoadedStateTracker implements IStateTracker {
  private _packages: Map<string, PackageState>;
  private _results: PackageResult[];
  private _failures: PackageResult[];
  private _startTimeMs: number;

  private constructor(
    packages: Map<string, PackageState>,
    results: PackageResult[],
    failures: PackageResult[],
    startTimeMs: number
  ) {
    this._packages = packages;
    this._results = results;
    this._failures = failures;
    this._startTimeMs = startTimeMs;
  }

  static async fromFileAsync(
    filePath: string
  ): Promise<LoadedStateTracker> {
    const raw = await fs.readFile(filePath, 'utf-8');
    const summary = JSON.parse(raw) as BatchSummary;
    return LoadedStateTracker.fromSummary(summary);
  }

  static fromSummary(summary: BatchSummary): LoadedStateTracker {
    const packages = new Map<string, PackageState>();
    const failures: PackageResult[] = [];

    for (const result of summary.packages) {
      packages.set(result.packageName, {
        name: result.packageName,
        status: result.success ? 'passed' : 'failed',
        durationMs: result.durationMs,
        result,
        progress: result.progressSummary,
      });
      if (!result.success) {
        failures.push(result);
      }
    }

    // Set startTimeMs so that Date.now() - startTimeMs ≈ summary.durationMs
    const startTimeMs = Date.now() - summary.summary.durationMs;

    return new LoadedStateTracker(
      packages,
      summary.packages,
      failures,
      startTimeMs
    );
  }

  get total(): number {
    return this._packages.size;
  }

  get completed(): number {
    return this._packages.size;
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

  getResults(): PackageResult[] {
    return this._results;
  }

  getFailures(): PackageResult[] {
    return this._failures;
  }

  getCurrentPhase(name: string): PackageStatus | undefined {
    return this._packages.get(name)?.status;
  }
}
