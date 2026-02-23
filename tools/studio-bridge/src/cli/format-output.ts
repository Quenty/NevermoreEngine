/**
 * CLI output formatting utilities. Wraps @quenty/cli-output-helpers
 * output-modes with convenient defaults for studio-bridge commands.
 */

import {
  resolveOutputMode,
  formatTable,
  formatJson,
  type OutputMode,
  type TableColumn,
} from '@quenty/cli-output-helpers/output-modes';

export type { OutputMode, TableColumn };

export interface FormatOptions {
  json?: boolean;
  isTTY?: boolean;
}

/**
 * Resolve the output mode based on CLI flags and TTY detection.
 */
export function resolveMode(options: FormatOptions): OutputMode {
  return resolveOutputMode({
    json: options.json,
    isTTY: options.isTTY ?? process.stdout.isTTY,
  });
}

/**
 * Format data as JSON, pretty-printing when connected to a TTY.
 */
export function formatAsJson(data: unknown): string {
  return formatJson(data, { pretty: process.stdout.isTTY });
}

/**
 * Format rows as a table using the cli-output-helpers table formatter.
 */
export function formatAsTable<T>(rows: T[], columns: TableColumn<T>[]): string {
  return formatTable(rows, columns);
}
