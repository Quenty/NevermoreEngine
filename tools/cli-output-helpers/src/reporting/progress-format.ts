/**
 * Formatting helpers for ProgressSummary values.
 */

import { type ProgressSummary, type JobPhase } from './reporter.js';

/**
 * Format progress for inline display in spinners and running status.
 * Returns empty string when progress is undefined.
 *
 * - test-counts: "(5/23)"
 * - bytes: "12.3 MB" or "45%"
 * - steps: "(3/10)"
 */
export function formatProgressInline(progress?: ProgressSummary): string {
  if (!progress) return '';

  switch (progress.kind) {
    case 'test-counts':
      return `(${progress.passed}/${progress.total})`;
    case 'bytes':
      if (progress.totalBytes > 0 && progress.transferredBytes > 0) {
        return `(${_formatBytes(progress.transferredBytes)}/${_formatBytes(progress.totalBytes)})`;
      }
      return `(${_formatBytes(progress.totalBytes)})`;
    case 'steps':
      if (progress.total > 0) {
        return `(${progress.completed}/${progress.total})`;
      }
      // Indeterminate: show label or just the count
      return progress.label ? `(${progress.label})` : `(${progress.completed})`;
  }
}

/**
 * Format progress for final result display (passed/failed lines).
 * Returns empty string when progress is undefined.
 *
 * - test-counts: "(23/100)" or "(0/0)"
 * - bytes: "(12.3 MB)"
 * - steps: "(3/10)"
 */
export function formatProgressResult(progress?: ProgressSummary): string {
  if (!progress) return '';

  switch (progress.kind) {
    case 'test-counts':
      return `(${progress.passed}/${progress.total})`;
    case 'bytes':
      return `(${_formatBytes(progress.totalBytes)})`;
    case 'steps':
      return `(${progress.completed}/${progress.total})`;
  }
}

/** True when progress is test-counts with total === 0. */
export function isEmptyTestRun(progress?: ProgressSummary): boolean {
  return progress?.kind === 'test-counts' && progress.total === 0;
}

/**
 * Condense a raw error string and optional failedPhase into a short one-liner.
 *
 * Examples:
 *   summarizeFailure("Upload failed: 409 Conflict: {...}", "uploading")
 *     → "at uploading: Upload failed (409)"
 *   summarizeFailure("timeout after 120s", "executing")
 *     → "at executing: timeout after 120s"
 */
export function summarizeFailure(
  error?: string,
  failedPhase?: JobPhase
): string {
  const parts: string[] = [];

  if (failedPhase) {
    parts.push(`at ${failedPhase}`);
  }

  if (error) {
    const firstLine = error.split('\n')[0];
    const short = firstLine.length > 60 ? firstLine.slice(0, 57) + '...' : firstLine;
    if (parts.length > 0) {
      parts.push(`: ${short}`);
    } else {
      parts.push(short);
    }
  }

  return parts.join('');
}

function _formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
