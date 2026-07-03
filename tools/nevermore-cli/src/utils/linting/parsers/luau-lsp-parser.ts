/**
 * Parser for luau-lsp analyze output.
 *
 * Format: `path(line,col): ErrorCode: message`
 * Example: `src/foo/Bar.lua(10,5): TypeMismatch: expected 'string', got 'number'`
 *
 * Diagnostics may span multiple lines — luau-lsp often emits expected/got type
 * literals on subsequent lines (indented) along with unindented connectives like
 * `but got`. Continuation lines are appended to the prior diagnostic's message
 * until a blank line, a new diagnostic header, or end-of-input.
 */

import {
  type Diagnostic,
  type DiagnosticSeverity,
} from '@quenty/cli-output-helpers/reporting';

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
const LINE_PATTERN = /^(.+?)\((\d+),(\d+)\): (\w+): (.+)$/;

export function parseLuauLspOutput(raw: string): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];
  let current: Diagnostic | undefined;
  let continuation: string[] = [];

  const flush = () => {
    if (!current) return;
    if (continuation.length > 0) {
      current.message = [current.message, ...continuation].join('\n');
    }
    diagnostics.push(current);
    current = undefined;
    continuation = [];
  };

  for (const line of raw.split('\n')) {
    const match = line.match(LINE_PATTERN);

    if (match) {
      flush();
      const [, file, lineStr, colStr, code, message] = match;
      const severity: DiagnosticSeverity = WARNING_CODES.has(code)
        ? 'warning'
        : 'error';
      current = {
        file,
        line: parseInt(lineStr, 10),
        column: parseInt(colStr, 10),
        severity,
        message,
        title: `luau-lsp(${code})`,
        source: 'luau-lsp',
      };
      continue;
    }

    // Blank line ends the current diagnostic's continuation block.
    if (line.trim() === '') {
      flush();
      continue;
    }

    // Non-blank, non-header line is a continuation of the prior diagnostic.
    if (current) {
      continuation.push(line);
    }
  }

  flush();
  return diagnostics;
}
