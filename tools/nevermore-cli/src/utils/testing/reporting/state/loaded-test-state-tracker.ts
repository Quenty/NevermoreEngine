import * as fs from 'fs/promises';
import {
  type BatchTestResult,
  type BatchTestSummary,
} from '../../runner/batch-test-runner.js';
import {
  type ITestStateTracker,
  type PackageState,
} from './test-state-tracker.js';

/**
 * Test state loaded from a previously-saved BatchTestSummary JSON file.
 * All packages are already in their final passed/failed state.
 */
export class LoadedTestStateTracker implements ITestStateTracker {
  private _packages: Map<string, PackageState>;
  private _results: BatchTestResult[];
  private _failures: BatchTestResult[];
  private _startTimeMs: number;

  private constructor(
    packages: Map<string, PackageState>,
    results: BatchTestResult[],
    failures: BatchTestResult[],
    startTimeMs: number
  ) {
    this._packages = packages;
    this._results = results;
    this._failures = failures;
    this._startTimeMs = startTimeMs;
  }

  static async fromFileAsync(
    filePath: string
  ): Promise<LoadedTestStateTracker> {
    const raw = await fs.readFile(filePath, 'utf-8');
    const summary = JSON.parse(raw) as BatchTestSummary;
    return LoadedTestStateTracker.fromSummary(summary);
  }

  static fromSummary(summary: BatchTestSummary): LoadedTestStateTracker {
    const packages = new Map<string, PackageState>();
    const failures: BatchTestResult[] = [];

    for (const result of summary.packages) {
      packages.set(result.packageName, {
        name: result.packageName,
        status: result.success ? 'passed' : 'failed',
        durationMs: result.durationMs,
        result,
      });
      if (!result.success) {
        failures.push(result);
      }
    }

    // Set startTimeMs so that Date.now() - startTimeMs ≈ summary.durationMs
    const startTimeMs = Date.now() - summary.summary.durationMs;

    return new LoadedTestStateTracker(
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

  getResults(): BatchTestResult[] {
    return this._results;
  }

  getFailures(): BatchTestResult[] {
    return this._failures;
  }
}
