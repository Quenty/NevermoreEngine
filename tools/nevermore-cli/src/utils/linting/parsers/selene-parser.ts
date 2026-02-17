/**
 * Parser for selene lint output.
 *
 * selene uses a multi-line format with a severity header and a location line:
 * ```
 * warning[unused_variable]: x is assigned a value, but never used
 *   ┌─ src/foo.lua:1:7
 *   │
 * 1 │ local x = 1
 *   │       ^
 * ```
 *
 * When run via `npx lerna exec --parallel`, output may be prefixed:
 * ```
 * @quenty/pkg: warning[unused_variable]: x is assigned a value, but never used
 * @quenty/pkg:   ┌─ src/foo.lua:1:7
 * ```
 *
 * The parser matches the severity header, then looks at subsequent lines
 * for the `┌─` location marker.
 */

import { type Diagnostic, type DiagnosticSeverity } from '@quenty/cli-output-helpers/reporting';
import {
  LERNA_PREFIX_PATTERN,
  LERNA_PREFIX_PATTERN_NC,
  resolvePackagePath,
} from './lerna-utils.js';

/**
 * Matches the severity header line.
 * Optional lerna prefix (captures package name).
 * Group 1: lerna package name (e.g. "acceltween") or undefined
 * Group 2: severity (error, warning)
 * Group 3: rule name
 * Group 4: message
 */
const SEVERITY_PATTERN = new RegExp(
  `^(?:${LERNA_PREFIX_PATTERN})?(error|warning)\\[(\\w+)\\]: (.+)$`
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
  rule: string;
  message: string;
  packageName: string | undefined;
}

export function parseSeleneOutput(raw: string): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];
  const lines = raw.split('\n');
  let pending: PendingDiagnostic | undefined;

  for (const line of lines) {
    // Try to match a severity header
    const sevMatch = line.match(SEVERITY_PATTERN);
    if (sevMatch) {
      const [, packageName, severity, rule, message] = sevMatch;
      pending = {
        severity: severity as DiagnosticSeverity,
        rule,
        message,
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
          title: `selene(${pending.rule})`,
          source: 'selene',
        });
        pending = undefined;
        continue;
      }
    }
  }

  return diagnostics;
}
