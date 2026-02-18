/**
 * Parser for luau-lsp analyze output.
 *
 * Format: `path(line,col): ErrorCode: message`
 * Example: `src/foo/Bar.lua(10,5): TypeMismatch: expected 'string', got 'number'`
 */

import { type Diagnostic, type DiagnosticSeverity } from '@quenty/cli-output-helpers/reporting';

/** Known warning-level diagnostic codes from luau-lsp. */
const WARNING_CODES = new Set([
  'LocalUnused',
  'FunctionUnused',
  'ImportUnused',
  'LocalShadow',
]);

/**
 * Match luau-lsp output lines.
 * Group 1: file path
 * Group 2: line number
 * Group 3: column number
 * Group 4: error code
 * Group 5: message
 */
const LINE_PATTERN =
  /^(.+?)\((\d+),(\d+)\): (\w+): (.+)$/;

export function parseLuauLspOutput(raw: string): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];

  for (const line of raw.split('\n')) {
    const match = line.match(LINE_PATTERN);
    if (!match) continue;

    const [, file, lineStr, colStr, code, message] = match;
    const severity: DiagnosticSeverity = WARNING_CODES.has(code)
      ? 'warning'
      : 'error';

    diagnostics.push({
      file,
      line: parseInt(lineStr, 10),
      column: parseInt(colStr, 10),
      severity,
      message,
      title: `luau-lsp(${code})`,
      source: 'luau-lsp',
    });
  }

  return diagnostics;
}
