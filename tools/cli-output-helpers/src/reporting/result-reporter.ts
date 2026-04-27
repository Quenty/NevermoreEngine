/**
 * Single-result reporter — for commands that produce one result (or a polled
 * series of results), as opposed to batch jobs with per-package lifecycle.
 *
 * Use this for any CLI command that:
 *   - Runs once and prints a result to stdout
 *   - Writes a result to a file via --output
 *   - Polls a result on an interval and redraws (--watch)
 *
 * For batch jobs (multi-package, lifecycle phases, progress events), use the
 * Reporter interface in reporter.ts instead.
 */

/**
 * Lifecycle hooks for a single-result reporter. Implementations decide how
 * to render the result (stdout, file, watch redraw, etc).
 */
export interface ResultReporter<T = unknown> {
  /** Called once before any results are reported. */
  startAsync(): Promise<void>;

  /**
   * Called when a result is available. May be called multiple times for
   * watch mode (each tick produces a fresh result).
   */
  onResult(result: T): void;

  /** Called once after the final result. */
  stopAsync(): Promise<void>;
}

/**
 * Base class with no-op defaults. Reporters extend this and override only
 * the hooks they need.
 */
export class BaseResultReporter<T = unknown> implements ResultReporter<T> {
  async startAsync(): Promise<void> {}
  onResult(_result: T): void {}
  async stopAsync(): Promise<void> {}
}
