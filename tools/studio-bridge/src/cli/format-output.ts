/**
 * studio-bridge CLI mode resolution. Extends the primitive `OutputMode`
 * (table | json | text) with `'base64'` for printing binary fields as raw
 * base64 strings to stdout.
 */

import {
  resolveOutputMode,
  type OutputMode,
} from '@quenty/cli-output-helpers/reporting';

/** Output modes recognized by the studio-bridge CLI. */
export type CliFormatMode = OutputMode | 'base64';

export interface FormatOptions {
  /** Value of `--format` flag, if any. */
  format?: string;
  /** TTY status; defaults to `process.stdout.isTTY`. */
  isTTY?: boolean;
}

/**
 * Resolve the CLI output mode from the `--format` flag, falling back to
 * TTY detection when no format is specified.
 */
export function resolveMode(options: FormatOptions): CliFormatMode {
  if (options.format === 'json') return 'json';
  if (options.format === 'text') return 'text';
  if (options.format === 'base64') return 'base64';
  return resolveOutputMode({ isTTY: options.isTTY ?? process.stdout.isTTY });
}

export type { OutputMode };
