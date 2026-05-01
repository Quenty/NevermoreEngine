/**
 * Factory that maps argv-style flags to the right concrete `ResultReporter`.
 * Encapsulates the "is this --output, --watch, or default stdout?" dispatch
 * so command frameworks don't have to know which reporter class to construct.
 */

import type { ResultReporter } from './result-reporter.js';
import { StdoutResultReporter } from './stdout-result-reporter.js';
import { FileResultReporter } from './file-result-reporter.js';
import { WatchResultReporter } from './watch-result-reporter.js';

export interface BuildResultReporterOptions<T> {
  /** Output file path; if set, returns a `FileResultReporter`. */
  outputPath?: string;
  /** When true (and no `outputPath`), returns a `WatchResultReporter`. */
  watch?: boolean;
  /** Open the output file after writing (`FileResultReporter` only). */
  open?: boolean;
  /** Polling interval for the `WatchResultReporter`. Default: 1000ms. */
  intervalMs?: number;
  /** Render result to a string. */
  render: (result: T) => string;
  /**
   * Optionally extract a binary buffer for `FileResultReporter`. When
   * provided and the buffer is non-undefined, the file write skips text
   * rendering and emits raw bytes instead.
   */
  binary?: (result: T) => Buffer | undefined;
}

/**
 * Build a `ResultReporter` from common argv-style flags. Selection rules:
 *
 *   - `outputPath` set      → `FileResultReporter`
 *   - else `watch` truthy   → `WatchResultReporter`
 *   - else                  → `StdoutResultReporter`
 */
export function buildResultReporter<T>(
  options: BuildResultReporterOptions<T>
): ResultReporter<T> {
  if (options.outputPath !== undefined) {
    return new FileResultReporter<T>({
      outputPath: options.outputPath,
      render: options.render,
      binary: options.binary,
      open: options.open,
    });
  }

  if (options.watch) {
    return new WatchResultReporter<T>({
      render: options.render,
      intervalMs: options.intervalMs,
    });
  }

  return new StdoutResultReporter<T>({ render: options.render });
}
