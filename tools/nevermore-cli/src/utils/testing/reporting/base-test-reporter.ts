import { type TestPhase } from '../runner/test-runner.js';
import { type BatchTestResult } from '../runner/batch-test-runner.js';

export type { TestPhase, BatchTestResult };

/** Unified status for a package moving through the test lifecycle. */
export type PackageTestStatus = 'pending' | TestPhase | 'passed' | 'failed';

/**
 * Lifecycle hooks for test execution reporting.
 *
 * Configuration (package lists, options, concurrency) stays in each
 * reporter's constructor — this interface is purely lifecycle hooks.
 */
export interface TestReporter {
  /** Called once before any tests run. */
  startAsync(): Promise<void>;

  /** Called when a package begins testing. */
  onPackageStart(packageName: string): void;

  /** Called when a package transitions phases (building, uploading, executing, etc). */
  onPackagePhaseChange(packageName: string, phase: TestPhase): void;

  /** Called when a single package test completes. */
  onPackageResult(result: BatchTestResult, bufferedOutput?: string[]): void;

  /** Called after all tests complete. */
  stopAsync(): Promise<void>;
}

/**
 * Base class with no-op defaults for all lifecycle hooks.
 * Reporters extend this and only override the methods they need.
 */
export class BaseTestReporter implements TestReporter {
  async startAsync(): Promise<void> {}
  onPackageStart(_packageName: string): void {}
  onPackagePhaseChange(_packageName: string, _phase: TestPhase): void {}
  onPackageResult(_result: BatchTestResult, _bufferedOutput?: string[]): void {}
  async stopAsync(): Promise<void> {}
}
