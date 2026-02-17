/**
 * Parser for stylua --check output.
 *
 * stylua --check prints a unified diff for each unformatted file:
 * ```
 * Diff in path/to/file.lua:
 * 1        |-local x   =    1
 *     1    |+local x = 1
 * ```
 *
 * Since stylua doesn't provide structured line-level diagnostics,
 * each file with a diff produces a single file-level warning at line 1.
 */

import { type Diagnostic } from '@quenty/cli-output-helpers/reporting';

/** Matches lines like `Diff in path/to/file.lua:` */
const DIFF_HEADER_PATTERN = /^Diff in (.+):$/;

export function parseStyluaOutput(raw: string): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];

  for (const line of raw.split('\n')) {
    const match = line.match(DIFF_HEADER_PATTERN);
    if (!match) continue;

    const [, file] = match;
    diagnostics.push({
      file,
      line: 1,
      severity: 'warning',
      message: 'File is not formatted. Run stylua to fix.',
      title: 'stylua',
      source: 'stylua',
    });
  }

  return diagnostics;
}
