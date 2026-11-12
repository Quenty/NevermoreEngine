import { randomUUID } from 'crypto';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  formatCount,
  formatCsv,
  toCsvField,
  type CsvValue,
  type TreeNode,
} from '@quenty/cli-output-helpers/reporting';
import {
  defineCommand,
  type ResultTable,
  type WatchStream,
} from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession } from '../../../bridge/index.js';
import type {
  InstanceRef,
  RecordingClock,
  SampleRollupRow,
  SampleRow,
  SampleScope,
  SampleValue,
  SampleValueRow,
} from '../../../server/web-socket-protocol.js';
import {
  recordingArgs,
  resolveOpenRecordingAsync,
  resolveRecordingAsync,
  type OpenRecordingPayload,
  type RecordingArgs,
  type RecordingPayload,
} from '../../shared/recording-args.js';
import { formatInstanceTree } from '../../shared/instance-tree.js';
import {
  removedSelectionOptions,
  selectionArgs,
  toInstanceQuery,
  type InstanceQuery,
  type SelectionArgs,
} from '../selection-args.js';

export type { SampleRow, SampleValueRow };

export interface SampleResult {
  instances: InstanceRef[];
  scope: SampleScope;
  watched: number;
  rows: SampleRow[];
  refs: Record<string, InstanceRef>;
  requested: string[];
  omitted: number;
  recorded: number;
  frameCount: number;
  elapsed: number;
  truncated: boolean;
  clock: RecordingClock;
  summary: string;
}

type SampleSelection = Omit<
  InstanceQuery,
  'grep' | 'luaPattern' | 'caseSensitive'
>;

interface SampleValues {
  selection?: boolean;
  properties?: string[];
  attributes?: string[];
}

export type SampleOptions = SampleSelection & RecordingPayload & SampleValues;

export type SampleWatchOptions = SampleSelection &
  OpenRecordingPayload &
  SampleValues;

const WATCH_WAIT_SECONDS = 0.5;

const DEFAULT_DURATION = '2s';

export const ROLLUP_NOTE =
  'Too many changes at once to list, so they are counted per group. Narrow with a query to see each change: a group path works as one';

export async function sampleInstancesHandlerAsync(
  session: BridgeSession,
  options: SampleOptions
): Promise<SampleResult> {
  const result = await session.sampleInstancesAsync(options);
  const sorted = {
    ...result,
    rows: sortRows(result.rows),
    requested: toRequested(options),
  };
  return { ...sorted, summary: summarize(sorted) };
}

function toRequested(values: SampleValues): string[] {
  return [
    ...(values.properties ?? []),
    ...(values.attributes ?? []).map((name) => `@${name}`),
  ];
}

export function sortRows(rows: SampleRow[]): SampleRow[] {
  return [...rows].sort(
    (a, b) =>
      a.frame - b.frame ||
      compareText(sortPath(a), sortPath(b)) ||
      compareProperty(sortProperty(a), sortProperty(b))
  );
}

function sortPath(row: SampleRow): string {
  return row.path === '' ? '\uffff' : row.path;
}

function sortProperty(row: SampleRow): string {
  return 'property' in row ? row.property ?? '' : '';
}

function compareText(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

const COMPONENT_ORDER = [
  'Position',
  'Orientation',
  'X',
  'Y',
  'Z',
  'R',
  'G',
  'B',
  'Scale',
  'Offset',
];

const AXES = new Set(COMPONENT_ORDER.slice(2));

function compareProperty(a: string, b: string): number {
  const partsA = a.split('.');
  const partsB = b.split('.');
  for (let i = 0; i < Math.min(partsA.length, partsB.length); i++) {
    if (partsA[i] === partsB[i]) continue;
    const rankA = i > 0 ? COMPONENT_ORDER.indexOf(partsA[i]) : -1;
    const rankB = i > 0 ? COMPONENT_ORDER.indexOf(partsB[i]) : -1;
    return rankA !== -1 && rankB !== -1
      ? rankA - rankB
      : compareText(partsA[i], partsB[i]);
  }
  return partsA.length - partsB.length;
}

export function toValueName(
  property: string,
  requested: ReadonlySet<string>
): string {
  let name = property;
  for (;;) {
    const dot = name.lastIndexOf('.');
    if (requested.has(name) || dot === -1 || !AXES.has(name.slice(dot + 1))) {
      return name;
    }
    name = name.slice(0, dot);
  }
}

function summarize(result: Omit<SampleResult, 'summary'>): string {
  const stopped = result.truncated ? ', stopped at --max-frames' : '';
  const changes = new SampleTextState(result.requested)
    .collect(result.rows)
    .flatMap((instance) => instance.spans)
    .reduce((sum, span) => sum + span.steps, 0);
  const counts = [formatCount(changes, 'change', 'changes')];
  for (const kind of ['added', 'removed'] as const) {
    const count = result.rows.filter((row) => row.kind === kind).length;
    if (count > 0) {
      counts.push(`${count} ${kind}`);
    }
  }
  const rollups = result.rows.filter((row) => row.kind === 'rollup').length;
  if (rollups > 0) {
    counts.push(formatCount(rollups, 'rolled-up group', 'rolled-up groups'));
  }
  const omitted =
    result.omitted > 0
      ? `. Left out ${formatCount(
          result.omitted,
          'more row',
          'more rows'
        )} past the cap; narrow with a query or a shorter --duration`
      : '';

  return `Sampled ${formatWatched(result.watched)}${formatScope(
    result.scope
  )} over ${result.recorded} frames (${result.elapsed.toFixed(
    3
  )}s${stopped}): ${counts.join(', ')}${omitted}`;
}

function formatWatched(count: number): string {
  return formatCount(count, 'instance', 'instances');
}

function formatScope(scope: SampleScope): string {
  if (scope === 'place') return ' in the place';
  if (scope === 'selection') return ' under the selection';
  return '';
}

export async function watchSampleAsync(
  session: BridgeSession,
  options: SampleWatchOptions,
  stream: WatchStream
): Promise<void> {
  const id = randomUUID();
  const state = new SampleTextState(toRequested(options));
  let isFirst = true;
  let hasNotedRollup = false;

  for (;;) {
    const isStopping = stream.signal.aborted;
    const result = await session.sampleInstancesAsync({
      ...options,
      watch: isStopping ? { id, stop: true } : { id, wait: WATCH_WAIT_SECONDS },
    });

    if (isFirst) {
      isFirst = false;
      OutputHelper.hint(
        `Watching ${formatWatched(result.watched)}${formatScope(
          result.scope
        )} for changes. Ctrl-C to stop`
      );
      if (result.instances.length > 0) {
        OutputHelper.hint(
          formatInstanceTree(result.instances, { linePrefix: '  ' })
        );
      }
      if (stream.format === 'csv') {
        stream.write(formatCsv(CSV_COLUMNS, []));
      }
    }

    if (
      !hasNotedRollup &&
      stream.format === 'text' &&
      result.rows.some((row) => row.kind === 'rollup')
    ) {
      hasNotedRollup = true;
      OutputHelper.hint(ROLLUP_NOTE);
    }

    const text = formatStreamedRows(
      sortRows(result.rows),
      result.refs,
      stream.format,
      state
    );
    if (text !== '') {
      stream.write(text);
    }

    if (isStopping || result.ended) {
      return;
    }
  }
}

function formatStreamedRows(
  rows: SampleRow[],
  refs: Record<string, InstanceRef>,
  format: WatchStream['format'],
  state: SampleTextState
): string {
  if (format === 'json' || format === 'csv') {
    return rows
      .map(
        (row) =>
          `${
            format === 'json'
              ? JSON.stringify(row)
              : toCsvLine(row).map(toCsvField).join(',')
          }\n`
      )
      .join('');
  }

  const lines = [
    formatChangeTree(state.collect(rows), refs, { linePrefix: '  ' }),
    ...rows
      .filter((row) => row.kind === 'rollup')
      .map((row) => `  ${formatRollup(row)}`),
  ].filter((line) => line !== '');
  if (lines.length === 0) {
    return '';
  }
  const latest = Math.max(...rows.map((row) => row.t));
  return `${formatTime(latest)}\n${lines.join('\n')}\n`;
}

export function parseNameList(values: string | string[] | undefined): string[] {
  return (values === undefined ? [] : [values].flat())
    .flatMap((value) => value.split(','))
    .map((name) => name.trim())
    .filter((name) => name !== '');
}

/** A property or attribute's changes on one instance, taken together. */
export interface ValueSpan {
  name: string;
  from: Map<string, SampleValue | undefined>;
  to: Map<string, SampleValue | undefined>;
  firstT: number;
  lastT: number;
  steps: number;
}

/** What happened to one instance. */
export interface InstanceChanges {
  path: string;
  spans: ValueSpan[];
  membership: Array<{ kind: 'added' | 'removed'; t: number }>;
}

export class SampleTextState {
  private _requested: ReadonlySet<string>;
  private _known = new Map<string, SampleValue>();
  private _components = new Map<string, string[]>();

  constructor(requested: string[]) {
    this._requested = new Set(requested);
  }

  public collect(rows: SampleRow[]): InstanceChanges[] {
    const instances = new Map<string, InstanceChanges>();
    const getInstance = (path: string): InstanceChanges => {
      let instance = instances.get(path);
      if (!instance) {
        instance = { path, spans: [], membership: [] };
        instances.set(path, instance);
      }
      return instance;
    };
    const spans = new Map<string, { path: string; span: ValueSpan }>();

    for (const frameRows of groupByFrame(rows)) {
      const changed = new Map<
        string,
        { path: string; name: string; t: number }
      >();
      for (const row of frameRows) {
        if (row.kind === 'added' || row.kind === 'removed') {
          getInstance(row.path).membership.push({ kind: row.kind, t: row.t });
        } else if (row.kind === 'value') {
          const name = toValueName(row.property, this._requested);
          const valueKey = `${row.path}\0${name}`;
          this._addComponent(valueKey, row.property);
          const key = `${row.path}\0${row.property}`;
          if (
            row.frame > 0 &&
            (!this._known.has(key) || this._known.get(key) !== row.value)
          ) {
            changed.set(valueKey, { path: row.path, name, t: row.t });
          }
        }
      }

      for (const [valueKey, { path, name, t }] of changed) {
        let entry = spans.get(valueKey);
        if (!entry) {
          entry = {
            path,
            span: {
              name,
              from: this._read(path, valueKey),
              to: new Map(),
              firstT: t,
              lastT: t,
              steps: 0,
            },
          };
          spans.set(valueKey, entry);
          getInstance(path).spans.push(entry.span);
        }
        entry.span.lastT = t;
        entry.span.steps++;
      }

      for (const row of frameRows) {
        if (row.kind === 'value') {
          this._known.set(`${row.path}\0${row.property}`, row.value);
        }
      }
    }

    for (const [valueKey, { path, span }] of spans) {
      span.to = this._read(path, valueKey);
    }
    return [...instances.values()];
  }

  private _addComponent(valueKey: string, component: string): void {
    const components = this._components.get(valueKey) ?? [];
    if (!components.includes(component)) {
      components.push(component);
      components.sort(compareProperty);
      this._components.set(valueKey, components);
    }
  }

  private _read(
    path: string,
    valueKey: string
  ): Map<string, SampleValue | undefined> {
    return new Map(
      (this._components.get(valueKey) ?? []).map((component) => [
        component,
        this._known.get(`${path}\0${component}`),
      ])
    );
  }
}

function groupByFrame(rows: SampleRow[]): SampleRow[][] {
  const frames: SampleRow[][] = [];
  for (const row of rows) {
    const last = frames[frames.length - 1];
    if (last && last[0].frame === row.frame) {
      last.push(row);
    } else {
      frames.push([row]);
    }
  }
  return frames;
}

function formatSpanChange(span: ValueSpan): string {
  const components = [...span.to.keys()];
  const to = components.map((component) => formatValue(span.to.get(component)));
  const from = components.map((component) => span.from.get(component));
  if (from.some((value) => value === undefined)) {
    return `→ ${to.join(', ')}`;
  }
  return `${from.map(formatValue).join(', ')} → ${to.join(', ')}`;
}

function formatValue(value: SampleValue | undefined): string {
  if (typeof value === 'number') {
    return String(Number(value.toFixed(4)));
  }
  return String(value);
}

function formatRollup(row: SampleRollupRow): string {
  const instances = `(${formatWatched(row.instances)})`;
  const changes = `×${formatCount(row.count, 'change', 'changes')}`;
  if (row.path === '') {
    return `…more groups ${instances}  ${changes}`;
  }

  const head = `${row.path}.** ${instances}`;
  if (row.property === '(added)' || row.property === '(removed)') {
    return `${head}  ${row.property === '(added)' ? '+ added' : '- removed'}`;
  }

  const parts = [head, row.property ?? '', changes];
  if (row.example !== undefined) {
    const value = row.value === undefined ? '' : ` = ${row.value}`;
    parts.push(OutputHelper.formatDim(`e.g. ${row.example}${value}`));
  }
  return parts.join('  ');
}

function formatChangeTree(
  instances: InstanceChanges[],
  refs: Record<string, InstanceRef>,
  options: { times?: boolean; linePrefix?: string }
): string {
  const entries = instances.map((changes) => ({
    ...(refs[changes.path] ?? toFallbackRef(changes.path)),
    changes,
  }));
  return formatInstanceTree(entries, {
    linePrefix: options.linePrefix,
    annotate: ({ changes }) => ({
      marker: changes.membership
        .map(({ kind }) => (kind === 'added' ? '+' : '-'))
        .join(''),
      annotation: options.times
        ? changes.membership.map(({ t }) => formatTime(t)).join(', ')
        : undefined,
    }),
    children: ({ changes }) => formatSpanLines(changes.spans, options.times),
  });
}

function toFallbackRef(path: string): InstanceRef {
  return { path, segments: path.split('.'), className: '' };
}

function formatSpanLines(spans: ValueSpan[], times?: boolean): TreeNode[] {
  const sorted = [...spans].sort((a, b) => compareProperty(a.name, b.name));
  const width = Math.max(0, ...sorted.map((span) => span.name.length));
  return sorted.map((span) => {
    const parts = [span.name.padEnd(width), formatSpanChange(span)];
    if (times) {
      parts.push(
        OutputHelper.formatDim(
          span.steps === 1
            ? formatTime(span.firstT)
            : `${formatTime(span.firstT)}–${formatTime(span.lastT)}, ${
                span.steps
              } steps`
        )
      );
    }
    return { label: parts.join('  ') };
  });
}

export function formatSampleText(result: SampleResult): string {
  const tree = formatChangeTree(
    new SampleTextState(result.requested).collect(result.rows),
    result.refs,
    { times: true }
  );
  const rollups = result.rows
    .filter((row) => row.kind === 'rollup')
    .map(
      (row) =>
        `${OutputHelper.formatDim(formatTime(row.t))}  ${formatRollup(row)}`
    );
  if (tree === '' && rollups.length === 0) {
    return formatInstanceTree(result.instances);
  }

  const notes = rollups.length > 0 ? [OutputHelper.formatDim(ROLLUP_NOTE)] : [];
  return [tree, ...rollups, ...notes].filter((line) => line !== '').join('\n');
}

function formatTime(t: number): string {
  return `${t.toFixed(2)}s`;
}

const CSV_COLUMNS = [
  'kind',
  't',
  'frame',
  'path',
  'property',
  'value',
  'count',
  'instances',
  'example',
] as const;

function toCsvLine(row: SampleRow): CsvValue[] {
  const fields = row as Partial<Record<typeof CSV_COLUMNS[number], CsvValue>>;
  return CSV_COLUMNS.map((column) => fields[column] ?? '');
}

export function toSampleTable(result: SampleResult): ResultTable {
  return { columns: CSV_COLUMNS, rows: result.rows.map(toCsvLine) };
}

interface SampleArgs extends SelectionArgs, RecordingArgs {
  selection?: boolean;
  properties?: string | string[];
  attributes?: string | string[];
}

function toSampleSelection(args: SampleArgs): SampleSelection & SampleValues {
  const { root, query, selector } = toInstanceQuery(args);
  return {
    root,
    query,
    selector,
    selection: args.selection || undefined,
    properties: parseNameList(args.properties),
    attributes: parseNameList(args.attributes),
  };
}

export const sampleCommand = defineCommand<SampleArgs, SampleResult>({
  group: 'explorer',
  name: 'sample',
  description:
    'Record how properties and attributes of instances change every frame, e.g. while a trigger plays a tween. Defaults to the whole place, to whatever changes, and to 2s',
  category: 'execution',
  safety: 'mutate',
  changesDataModel: true,
  scope: 'session',
  args: {
    ...selectionArgs,
    query: {
      ...selectionArgs.query,
      description: `${selectionArgs.query.description}. Default: the whole place`,
    },
    selection: arg.flag({
      description:
        'Watch the instances selected in Studio and their descendants, instead of the whole place',
    }),
    properties: arg.option({
      description:
        'Properties to record every frame, comma-separated or repeated. JSON and CSV split composite values per component (Size.X.Scale), and a component can be asked for. Without these or --attributes, records whatever changes',
    }),
    attributes: arg.option({
      description:
        'Attributes to record every frame, comma-separated or repeated. Rows name them @Name',
    }),
    ...recordingArgs,
    duration: {
      ...recordingArgs.duration,
      required: false,
      description: `${recordingArgs.duration.description}. Default: ${DEFAULT_DURATION}, or until Ctrl-C with --watch`,
    },
  },
  cli: {
    body: formatSampleText,
    removedOptions: removedSelectionOptions,
    rows: toSampleTable,
    watch: {
      description: 'Print changes as they happen, until Ctrl-C or --duration',
      handler: async (session, args, stream) =>
        watchSampleAsync(
          session,
          {
            ...toSampleSelection(args),
            ...(await resolveOpenRecordingAsync(args)),
          },
          stream
        ),
    },
  },
  handler: async (session, args) =>
    sampleInstancesHandlerAsync(session, {
      ...toSampleSelection(args),
      ...(await resolveRecordingAsync({
        ...args,
        duration: args.duration ?? DEFAULT_DURATION,
      })),
    }),
});
