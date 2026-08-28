import { OutputHelper } from '@quenty/cli-output-helpers';
import { formatDurationMs } from '@quenty/cli-output-helpers/cli-utils';
import {
  formatStatusText,
  resolveResultStatus,
  statusIcon,
  type ResultStatusInput,
} from '@quenty/cli-output-helpers/reporting';
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
  /** Slugs that reached the output, so the rest can be listed after it. */
  const rendered = new Set<string>();
  let openSlug: string | undefined;
  /**
   * Where the run of lines belonging to no open section began.
   *
   * A section whose BEGIN the log window dropped only announces itself at its
   * END, by which point its output has already been emitted. Knowing where that
   * run started lets the header be spliced in above it, so the output lands
   * inside its own group rather than the group holding only a verdict.
   */
  let orphanStart = 0;

  const closeGroup = (): void => {
    if (openSlug === undefined) {
      return;
    }
    if (options.useGroups) {
      out.push('::endgroup::');
    }
    openSlug = undefined;
    orphanStart = out.length;
  };

  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];

    if (token.kind === 'begin') {
      // A second BEGIN with a section still open means the first never closed;
      // close it here so the groups stay balanced whatever the log did.
      closeGroup();
      openSlug = token.slug;
      rendered.add(token.slug);
      out.push(...openGroup(token.slug, options));
      continue;
    }

    if (token.kind === 'end') {
      if (openSlug === undefined) {
        // An END whose BEGIN the log window dropped. Its output is already in
        // `out`, so the header goes in above it rather than here — otherwise
        // the group holds nothing but the verdict while the output it belongs
        // to sits loose above it.
        out.splice(orphanStart, 0, ...openGroup(token.slug, options));
        openSlug = token.slug;
      }
      rendered.add(token.slug);
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
  out.push(...sectionlessGroups(rendered, options));

  return out;
}

/**
 * Groups for packages that never appeared in the log at all.
 *
 * A dropped log window takes whole sections with it, markers included, and such
 * a package used to render nothing: no group, no verdict, no reason — only a
 * row in the summary table saying FAILED with nothing behind it. The result is
 * known regardless, because it came back in the run's return value, so it is
 * shown in the same shape every other package is.
 */
function sectionlessGroups(
  rendered: Set<string>,
  options: BatchLogRenderOptions
): string[] {
  const out: string[] = [];

  for (const [slug, name] of options.slugToPackage) {
    if (rendered.has(slug)) {
      continue;
    }
    const result = options.results?.get(name);
    if (!result) {
      continue;
    }

    out.push(...openGroup(slug, options));
    out.push(...verdictLines(slug, options));
    // The group is otherwise empty, so it says why rather than leaving a reader
    // to work out that a package showing no output is one whose output is gone.
    out.push(
      options.color ? OutputHelper.formatDim(NO_SECTION_NOTE) : NO_SECTION_NOTE
    );
    if (options.useGroups) {
      out.push('::endgroup::');
    }
  }

  return out;
}

const NO_SECTION_NOTE =
  "This package printed nothing that survived the run's log window. " +
  'Its verdict and counts came back in the batch summary instead.';

/**
 * Render everything one batch execution produced, ready to print.
 *
 * The binding between what a run reports and what the renderer is told about it
 * lives here rather than at the call site, so a field the outcome carries and
 * the render forgets — the results that put a verdict in every group title, say
 * — is a mistake one test can catch.
 *
 * Structural rather than typed against `BatchExecutionOutcome`: the job context
 * that defines it already imports this module.
 */
export function renderBatchOutcome(
  outcome: {
    lines: RenderableLogLine[];
    results: Map<string, BatchPackageResult>;
    slugToPackage: Map<string, string>;
  },
  presentation: { useGroups: boolean; color: boolean }
): string[] {
  return renderBatchLog(outcome.lines, {
    slugToPackage: outcome.slugToPackage,
    results: outcome.results,
    useGroups: presentation.useGroups,
    color: presentation.color,
  });
}

/**
 * Header for one package's section, carrying its verdict.
 *
 * The status is in the title because a group is read collapsed: a reader
 * scanning 78 of them wants to know which to open, and a title that is only a
 * package name makes them all look alike. The counts and duration are formatted
 * with the same helpers the PR comment table uses, so the two cannot drift into
 * describing the same run differently.
 */
function openGroup(slug: string, options: BatchLogRenderOptions): string[] {
  const name = options.slugToPackage.get(slug) ?? slug;
  const result = options.results?.get(name);
  const title = result ? `${name} - ${describeResult(result)}` : name;

  if (options.useGroups) {
    return [`::group::${title}`];
  }

  return [OutputHelper.formatDim(`──────── ${title} ────────`)];
}

/**
 * "⚠️ Passed (35/35) - Logs lost (1.2s)", the shape every other reporter uses.
 *
 * Resolved by the shared status resolver rather than worked out here, so a
 * group title, a summary-table row and a PR comment row describing the same run
 * cannot disagree about what state it is in or what that state is called. This
 * only picks the icon style and puts the duration on the end.
 */
function describeResult(result: BatchPackageResult): string {
  const status = resolveResultStatus(toStatusInput(result));
  const duration =
    result.durationMs === undefined
      ? ''
      : `(${formatDurationMs(result.durationMs)})`;

  return [
    statusIcon(status.severity, 'emoji'),
    formatStatusText(status),
    duration,
  ]
    .filter(Boolean)
    .join(' ');
}

/**
 * A batch result in the shape the status resolver reads.
 *
 * The parser's result is not a `PackageResult` — it is per-section, and one
 * section is not a package's whole run — so the two fields the resolver needs
 * are handed over rather than the type being widened to fit.
 */
function toStatusInput(result: BatchPackageResult): ResultStatusInput {
  return {
    success: result.success,
    progressSummary: result.testCounts
      ? {
          kind: 'test-counts',
          passed: result.testCounts.passed,
          failed: result.testCounts.failed,
          total: result.testCounts.total,
        }
      : undefined,
    caveats: result.logsLost ? ['logs-lost'] : undefined,
  };
}

/**
 * Why a package failed, printed where its output ends.
 *
 * Only the reason: the verdict itself is in the group's title now, and saying
 * it twice in six lines of output reads as two separate findings. A reason is
 * a sentence and belongs in the body.
 */
function verdictLines(slug: string, options: BatchLogRenderOptions): string[] {
  const name = options.slugToPackage.get(slug);
  const result = name ? options.results?.get(name) : undefined;
  if (!result?.error) {
    return [];
  }

  return [
    options.color ? OutputHelper.formatError(result.error) : result.error,
  ];
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
