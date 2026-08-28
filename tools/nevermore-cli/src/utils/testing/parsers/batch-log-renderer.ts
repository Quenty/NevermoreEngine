import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type BatchPackageResult,
  tokenizeBatchLog,
} from './batch-log-parser.js';

/**
 * One line of a batch run's output, carrying the severity Open Cloud reported
 * for the message it came from.
 *
 * Severity is per *message*, and a message can be several lines — an error
 * arrives with its whole traceback attached — so every line of a message
 * inherits it. That is why this is not derived from the text: guessing at
 * severity from patterns misreads a traceback's continuation lines, while the
 * API already says which of OUTPUT, WARNING and ERROR each message was.
 */
export interface RenderableLogLine {
  line: string;
  severity: 'output' | 'warning' | 'error';
}

export interface BatchLogRenderOptions {
  /** Section slug to the package name a reader recognizes, for group titles. */
  slugToPackage: Map<string, string>;
  /**
   * Per-package verdicts, printed as each section closes so a package's result
   * sits with the output that produced it rather than in a later block.
   *
   * Keyed by package name, as `parseBatchTestLogs` returns it — sections are
   * named by slug, so a lookup here goes through `slugToPackage` first.
   */
  results?: Map<string, BatchPackageResult>;
  /** Emit GitHub `::group::` markers. Off outside CI, where they are noise. */
  useGroups: boolean;
  /** Colorize by severity. Off when NO_COLOR is set. */
  color: boolean;
}

/**
 * Split typed messages into the lines the parser tokenizes, keeping severity.
 *
 * The join is the same one `getRawTaskLogsAsync` performs, so the resulting
 * lines are positionally identical to the parser's — which is what lets the
 * token at index i describe the line at index i.
 */
export function toRenderableLines(
  messages: Array<{ message: string; messageType?: string }>
): RenderableLogLine[] {
  const lines: RenderableLogLine[] = [];

  for (const entry of messages) {
    const severity =
      entry.messageType === 'ERROR'
        ? 'error'
        : entry.messageType === 'WARNING'
        ? 'warning'
        : 'output';

    for (const line of entry.message.split('\n')) {
      lines.push({ line, severity });
    }
  }

  return lines;
}

/**
 * Render a whole batch run's output in arrival order, with each package's
 * section wrapped in a collapsible group.
 *
 * Every line the run produced is emitted, including the ones that belong to no
 * package: output between two sections, or before the first BEGIN, used to be
 * discarded by the parser and so never reached anyone. Those lines are exactly
 * the ones worth seeing when a batch misbehaves — a crash between packages, or
 * a harness message printed before the first test — so they are rendered at the
 * top level, outside any group, rather than dropped.
 *
 * Groups are injected around the parser's own BEGIN/END tokens rather than
 * opened as each package starts. An aggregated batch starts every package at
 * once, before the cloud task exists, so grouping by start time produced one
 * empty group per package and put every line under the last of them.
 */
export function renderBatchLog(
  lines: RenderableLogLine[],
  options: BatchLogRenderOptions
): string[] {
  const tokens = tokenizeBatchLog(lines.map((entry) => entry.line));
  const out: string[] = [];
  let openSlug: string | undefined;

  const closeGroup = (): void => {
    if (openSlug === undefined) {
      return;
    }
    if (options.useGroups) {
      out.push('::endgroup::');
    }
    openSlug = undefined;
  };

  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];

    if (token.kind === 'begin') {
      // A second BEGIN with a section still open means the first never closed;
      // close it here so the groups stay balanced whatever the log did.
      closeGroup();
      openSlug = token.slug;
      out.push(...openGroup(token.slug, options));
      continue;
    }

    if (token.kind === 'end') {
      if (openSlug === undefined) {
        // An END whose BEGIN was dropped by the log window. Its output has been
        // printing at the top level, so give it a header rather than silently
        // closing a group that was never opened.
        out.push(...openGroup(token.slug, options));
        openSlug = token.slug;
      }
      out.push(...verdictLines(token.slug, options));
      closeGroup();
      continue;
    }

    // The summary marker and its JSON payload are framing for the parser, not
    // output anyone reads.
    if (token.kind === 'summary' || token.kind === 'summaryPayload') {
      continue;
    }

    out.push(colorize(lines[i], options.color));
  }

  closeGroup();
  return out;
}

/** Header for one package's section. */
function openGroup(slug: string, options: BatchLogRenderOptions): string[] {
  const name = options.slugToPackage.get(slug) ?? slug;

  if (options.useGroups) {
    return [`::group::${name}`];
  }

  return [OutputHelper.formatDim(`──────── ${name} ────────`)];
}

/** The package's verdict, printed where its output ends. */
function verdictLines(slug: string, options: BatchLogRenderOptions): string[] {
  const name = options.slugToPackage.get(slug);
  const result = name ? options.results?.get(name) : undefined;
  if (!result) {
    return [];
  }

  const icon = result.success ? '✓' : '✗';
  const label = result.success ? 'Passed' : 'FAILED';
  const counts = result.testCounts
    ? ` (${result.testCounts.passed} passed, ${result.testCounts.failed} failed, ${result.testCounts.total} total)`
    : '';
  const headline = `${icon} ${label}${counts}`;

  const lines = [
    options.color
      ? result.success
        ? OutputHelper.formatSuccess(headline)
        : OutputHelper.formatError(headline)
      : headline,
  ];

  if (result.error) {
    lines.push(
      options.color ? OutputHelper.formatError(result.error) : result.error
    );
  }

  return lines;
}

function colorize(entry: RenderableLogLine, color: boolean): string {
  if (!color || entry.severity === 'output') {
    // Left exactly as it arrived: jest-lua colors its own output, and
    // re-wrapping it would fight those escapes.
    return entry.line;
  }

  return entry.severity === 'error'
    ? OutputHelper.formatError(entry.line)
    : OutputHelper.formatWarning(entry.line);
}
