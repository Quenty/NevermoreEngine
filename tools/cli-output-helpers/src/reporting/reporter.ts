/**
 * Generic batch job reporting framework.
 *
 * Jobs progress through phases (building → uploading → scheduling → executing)
 * and end in a terminal state (passed / failed).
 */

/** Execution phases a package can move through. */
export type JobPhase = 'waiting' | 'building' | 'downloading' | 'merging' | 'combining' | 'uploading' | 'scheduling' | 'launching' | 'connecting' | 'executing';

/** Unified status for a package moving through the job lifecycle. */
export type PackageStatus = 'pending' | JobPhase | 'passed' | 'failed';

// ── Progress summary types ─────────────────────────────────────────────────

/** Test count progress: "23/100 passed" */
export interface TestCountProgress {
  kind: 'test-counts';
  passed: number;
  failed: number;
  total: number;
}

/** Byte-level transfer progress: "45% of 12.3 MB" */
export interface ByteProgress {
  kind: 'bytes';
  transferredBytes: number;
  totalBytes: number;
}

/** Generic step progress: "3/10 packages" */
export interface StepProgress {
  kind: 'steps';
  completed: number;
  total: number;
  label?: string;
}

export type ProgressSummary = TestCountProgress | ByteProgress | StepProgress;

/** Result for a single package in a batch run. */
export interface PackageResult {
  packageName: string;
  success: boolean;
  logs: string;
  durationMs: number;
  error?: string;
  progressSummary?: ProgressSummary;
  failedPhase?: JobPhase;
}

/** Summary of a complete batch run. */
export interface BatchSummary<TResult extends PackageResult = PackageResult> {
  packages: TResult[];
  summary: {
    total: number;
    passed: number;
    failed: number;
    durationMs: number;
  };
}

/**
 * Lifecycle hooks for batch job reporting.
 *
 * Configuration (package lists, options, concurrency) stays in each
 * reporter's constructor — this interface is purely lifecycle hooks.
 */
export interface Reporter {
  /** Called once before any jobs run. */
  startAsync(): Promise<void>;

  /** Called when a package begins processing. */
  onPackageStart(packageName: string): void;

  /** Called when a package transitions phases (building, uploading, executing, etc). */
  onPackagePhaseChange(packageName: string, phase: JobPhase): void;

  /** Called when a package's in-progress metrics update (high-frequency). */
  onPackageProgressUpdate(packageName: string, progress: ProgressSummary): void;

  /** Called when a single package job completes. */
  onPackageResult(result: PackageResult, bufferedOutput?: string[]): void;

  /** Called after all jobs complete. */
  stopAsync(): Promise<void>;
}

/**
 * Base class with no-op defaults for all lifecycle hooks.
 * Reporters extend this and only override the methods they need.
 */
export class BaseReporter implements Reporter {
  async startAsync(): Promise<void> {}
  onPackageStart(_packageName: string): void {}
  onPackagePhaseChange(_packageName: string, _phase: JobPhase): void {}
  onPackageProgressUpdate(_packageName: string, _progress: ProgressSummary): void {}
  onPackageResult(_result: PackageResult, _bufferedOutput?: string[]): void {}
  async stopAsync(): Promise<void> {}
}
