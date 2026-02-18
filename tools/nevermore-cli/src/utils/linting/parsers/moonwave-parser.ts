/**
 * Parser for moonwave-extractor output.
 *
 * moonwave-extractor uses a Rust-style diagnostic format similar to selene:
 * ```
 * error: Unknown tag
 *   ┌─ src/foo.lua:3:3
 *   │
 * 3 │   @unclosedtag
 *   │   ^^^^^^^^^^^^ Unknown tag
 * ```
 *
 * When run via `npx lerna exec --parallel`, output may be prefixed:
 * ```
 * @quenty/pkg: error: Unknown tag
 * @quenty/pkg:   ┌─ src/foo.lua:3:3
 * ```
 *
 * The parser matches the severity header, then looks for the `┌─` location.
 * moonwave only emits errors (no warnings).
 */

import { type Diagnostic, type DiagnosticSeverity } from '@quenty/cli-output-helpers/reporting';
import {
  LERNA_PREFIX_PATTERN,
  LERNA_PREFIX_PATTERN_NC,
  resolvePackagePath,
} from './lerna-utils.js';

/** Strip all ANSI escape sequences from a string. */
const ANSI_PATTERN = /\x1b\[[0-9;]*m/g;
function _stripAnsi(text: string): string {
  return text.replace(ANSI_PATTERN, '');
}

/**
 * Matches the severity header line.
 * Optional lerna prefix (captures package name).
 * Group 1: lerna package name or undefined
 * Group 2: severity (error, warning)
 * Group 3: message
 */
const SEVERITY_PATTERN = new RegExp(
  `^(?:${LERNA_PREFIX_PATTERN})?\\s*(error|warning):\\s*(.+)$`
);

/**
 * Matches the location line with the `┌─` marker.
 * Optional lerna prefix (non-capturing).
 */
const LOCATION_PATTERN = new RegExp(
  `^(?:${LERNA_PREFIX_PATTERN_NC})?\\s+┌─ (.+?):(\\d+):(\\d+)`
);

interface PendingDiagnostic {
  severity: DiagnosticSeverity;
  message: string;
  packageName: string | undefined;
}

export function parseMoonwaveOutput(raw: string): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];
  const lines = raw.split('\n');
  let pending: PendingDiagnostic | undefined;

  for (const rawLine of lines) {
    const line = _stripAnsi(rawLine);

    // Skip the "aborting due to diagnostic error" summary line
    if (line.includes('aborting due to')) continue;

    // Try to match a severity header
    const sevMatch = line.match(SEVERITY_PATTERN);
    if (sevMatch) {
      const [, packageName, severity, message] = sevMatch;
      pending = {
        severity: severity as DiagnosticSeverity,
        message: message.trim(),
        packageName,
      };
      continue;
    }

    // Try to match a location line (only if we have a pending header)
    if (pending) {
      const locMatch = line.match(LOCATION_PATTERN);
      if (locMatch) {
        const [, rawFile, lineStr, colStr] = locMatch;
        const file = resolvePackagePath(pending.packageName, rawFile);
        diagnostics.push({
          file,
          line: parseInt(lineStr, 10),
          column: parseInt(colStr, 10),
          severity: pending.severity,
          message: pending.message,
          title: 'moonwave',
          source: 'moonwave',
        });
        pending = undefined;
        continue;
      }
    }
  }

  return diagnostics;
}
