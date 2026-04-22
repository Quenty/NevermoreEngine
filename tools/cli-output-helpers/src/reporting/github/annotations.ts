/**
 * GitHub Actions workflow annotation helpers.
 *
 * Emits `::error` / `::warning` / `::notice` workflow commands to stdout,
 * which GitHub renders as inline annotations on the PR diff.
 *
 * Also provides helpers to write a markdown summary to `$GITHUB_STEP_SUMMARY`.
 */

import * as fs from 'fs/promises';
import { OutputHelper } from '../../outputHelper.js';
import { isCI } from '../../cli-utils.js';

// ── Types ───────────────────────────────────────────────────────────────────

export type DiagnosticSeverity = 'error' | 'warning' | 'notice';

export interface Diagnostic {
  file: string;
  line: number;
  endLine?: number;
  column?: number;
  endColumn?: number;
  severity: DiagnosticSeverity;
  message: string;
  title?: string;
  source?: string;
}

export interface DiagnosticSummary {
  errors: number;
  warnings: number;
  notices: number;
  total: number;
  fileCount: number;
}

// ── Escaping ────────────────────────────────────────────────────────────────

/**
 * Escape a workflow command property value per the GitHub Actions spec.
 * Properties use `,` and `:` as delimiters, so those must be escaped.
 */
function _escapeProperty(value: string): string {
  return value
    .replace(/%/g, '%25')
    .replace(/\r/g, '%0D')
    .replace(/\n/g, '%0A')
    .replace(/:/g, '%3A')
    .replace(/,/g, '%2C');
}

/** Escape a workflow command message (data portion). */
function _escapeMessage(value: string): string {
  return value
    .replace(/%/g, '%25')
    .replace(/\r/g, '%0D')
    .replace(/\n/g, '%0A');
}

// ── Annotation emission ─────────────────────────────────────────────────────

/** Format a single diagnostic as a GitHub Actions workflow command. */
export function formatAnnotation(diagnostic: Diagnostic): string {
  const props: string[] = [];

  props.push(`file=${_escapeProperty(diagnostic.file)}`);
  props.push(`line=${diagnostic.line}`);

  if (diagnostic.endLine !== undefined) {
    props.push(`endLine=${diagnostic.endLine}`);
  }
  if (diagnostic.column !== undefined) {
    props.push(`col=${diagnostic.column}`);
  }
  if (diagnostic.endColumn !== undefined) {
    props.push(`endColumn=${diagnostic.endColumn}`);
  }
  if (diagnostic.title) {
    props.push(`title=${_escapeProperty(diagnostic.title)}`);
  }

  const message = _escapeMessage(diagnostic.message);
  return `::${diagnostic.severity} ${props.join(',')}::${message}`;
}

/**
 * Emit workflow annotation commands for each diagnostic to stdout.
 * GitHub Actions parses these from stdout and creates inline annotations.
 */
export function emitAnnotations(diagnostics: Diagnostic[]): void {
  for (const d of diagnostics) {
    console.log(formatAnnotation(d));
  }
}

// ── Summary helpers ─────────────────────────────────────────────────────────

/** Count diagnostics by severity and unique files. */
export function summarizeDiagnostics(
  diagnostics: Diagnostic[]
): DiagnosticSummary {
  let errors = 0;
  let warnings = 0;
  let notices = 0;
  const files = new Set<string>();

  for (const d of diagnostics) {
    files.add(d.file);
    switch (d.severity) {
      case 'error':
        errors++;
        break;
      case 'warning':
        warnings++;
        break;
      case 'notice':
        notices++;
        break;
    }
  }

  return {
    errors,
    warnings,
    notices,
    total: diagnostics.length,
    fileCount: files.size,
  };
}

/** Format a markdown summary suitable for `$GITHUB_STEP_SUMMARY`. */
export function formatAnnotationSummaryMarkdown(
  linterName: string,
  diagnostics: Diagnostic[]
): string {
  const summary = summarizeDiagnostics(diagnostics);

  let md = `### ${linterName}\n\n`;

  if (summary.total === 0) {
    md += `No issues found.\n`;
    return md;
  }

  const parts: string[] = [];
  if (summary.errors > 0) {
    parts.push(`${summary.errors} error${summary.errors !== 1 ? 's' : ''}`);
  }
  if (summary.warnings > 0) {
    parts.push(
      `${summary.warnings} warning${summary.warnings !== 1 ? 's' : ''}`
    );
  }
  if (summary.notices > 0) {
    parts.push(
      `${summary.notices} notice${summary.notices !== 1 ? 's' : ''}`
    );
  }

  md += `**${summary.total} issue${summary.total !== 1 ? 's' : ''}** across ${summary.fileCount} file${summary.fileCount !== 1 ? 's' : ''}: ${parts.join(', ')}\n\n`;

  // Group diagnostics by file
  const byFile = new Map<string, Diagnostic[]>();
  for (const d of diagnostics) {
    const list = byFile.get(d.file) ?? [];
    list.push(d);
    byFile.set(d.file, list);
  }

  // Table per file (capped to avoid overwhelming the summary)
  const MAX_FILES = 20;
  const MAX_PER_FILE = 10;
  let fileCount = 0;

  for (const [file, diags] of byFile) {
    if (fileCount >= MAX_FILES) {
      md += `\n_... and ${byFile.size - MAX_FILES} more file(s)_\n`;
      break;
    }

    md += `<details><summary><code>${file}</code> (${diags.length})</summary>\n\n`;
    md += '| Line | Severity | Message |\n';
    md += '|------|----------|---------|\n';

    const shown = diags.slice(0, MAX_PER_FILE);
    for (const d of shown) {
      const sev =
        d.severity === 'error'
          ? '`error`'
          : d.severity === 'warning'
            ? '`warning`'
            : '`notice`';
      const escapedMsg = d.message.replace(/\|/g, '\\|').replace(/\n/g, ' ');
      md += `| ${d.line} | ${sev} | ${escapedMsg} |\n`;
    }

    if (diags.length > MAX_PER_FILE) {
      md += `\n_... and ${diags.length - MAX_PER_FILE} more issue(s) in this file_\n`;
    }

    md += '\n</details>\n\n';
    fileCount++;
  }

  return md;
}

/**
 * Append a lint summary to `$GITHUB_STEP_SUMMARY`.
 * No-ops gracefully outside of GitHub Actions.
 */
export async function writeAnnotationSummaryAsync(
  linterName: string,
  diagnostics: Diagnostic[]
): Promise<void> {
  if (!isCI() || !process.env.GITHUB_STEP_SUMMARY) {
    return;
  }

  const markdown = formatAnnotationSummaryMarkdown(linterName, diagnostics);
  const summaryPath = process.env.GITHUB_STEP_SUMMARY;

  try {
    await fs.appendFile(summaryPath, markdown);
    OutputHelper.info('Written lint results to GitHub job summary.');
  } catch (err) {
    OutputHelper.warn(
      `Failed to write job summary: ${err instanceof Error ? err.message : String(err)}`
    );
  }
}
