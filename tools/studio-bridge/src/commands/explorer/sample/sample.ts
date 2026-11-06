/**
 * `explorer sample` — record properties and attributes of instances over a
 * window of frames, optionally after running a trigger, as one row per value
 * per frame.
 */

import { OutputHelper } from '@quenty/cli-output-helpers';
import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession } from '../../../bridge/index.js';
import { formatCsv } from '../../../encoders/index.js';
import type {
  RecordingClock,
  SampleRow,
} from '../../../server/web-socket-protocol.js';
import {
  recordingArgs,
  resolveRecordingAsync,
  type RecordingArgs,
  type RecordingPayload,
} from '../../shared/recording-args.js';
import {
  assertHasCriteria,
  selectionArgs,
  toInstanceSelection,
  type InstanceSelection,
  type SelectionArgs,
} from '../selection-args.js';

export type { SampleRow };

export interface SampleResult {
  /** Paths of the instances matched in frame 0. */
  instances: string[];
  rows: SampleRow[];
  /** Frames recorded. */
  recorded: number;
  /** Frames stepped through, frame 0 included. */
  frameCount: number;
  elapsed: number;
  truncated: boolean;
  clock: RecordingClock;
  summary: string;
}

export interface SampleOptions extends InstanceSelection, RecordingPayload {
  properties?: string[];
  attributes?: string[];
}

export async function sampleInstancesHandlerAsync(
  session: BridgeSession,
  options: SampleOptions
): Promise<SampleResult> {
  const { name: _name, ...rest } = options;
  const selection = assertHasCriteria(options, 'sample');
  if (!options.properties?.length && !options.attributes?.length) {
    throw new Error('Give --properties or --attributes to sample');
  }

  const result = await session.sampleInstancesAsync({ ...rest, ...selection });
  const stopped = result.truncated ? ', stopped at --max-frames' : '';

  return {
    ...result,
    summary: `Sampled ${result.instances.length} instance(s) over ${
      result.recorded
    } frames (${result.elapsed.toFixed(3)}s${stopped}): ${
      result.rows.length
    } values`,
  };
}

/**
 * Splits names given as repeats, comma lists or both (`--properties Size,Position
 * --properties Scale`) into one list. yargs passes a repeated option as an array.
 */
export function parseNameList(values: string | string[] | undefined): string[] {
  return (values === undefined ? [] : [values].flat())
    .flatMap((value) => value.split(','))
    .map((name) => name.trim())
    .filter((name) => name !== '');
}

export function formatSampleText(result: SampleResult): string {
  return [
    result.summary,
    ...result.instances.map((path) => OutputHelper.formatDim(`  ${path}`)),
  ].join('\n');
}

const CSV_COLUMNS = ['t', 'frame', 'path', 'property', 'value'] as const;

/** The rows as CSV, one column per row field. */
export function formatSampleCsv(result: SampleResult): string {
  return formatCsv(
    CSV_COLUMNS,
    result.rows.map((row) => CSV_COLUMNS.map((column) => row[column]))
  );
}

interface SampleArgs extends SelectionArgs, RecordingArgs {
  properties?: string | string[];
  attributes?: string | string[];
}

export const sampleCommand = defineCommand<SampleArgs, SampleResult>({
  group: 'explorer',
  name: 'sample',
  description:
    'Record properties and attributes of instances every frame, e.g. while a trigger plays a tween',
  category: 'execution',
  // A trigger runs arbitrary code
  safety: 'mutate',
  changesDataModel: true,
  scope: 'session',
  args: {
    ...selectionArgs,
    // Not array options, which would take the names after them too
    properties: arg.option({
      description:
        'Properties to record, comma-separated or repeated. Composite values split per component (Size.X.Scale)',
    }),
    attributes: arg.option({
      description:
        'Attributes to record, comma-separated or repeated. Rows name them @Name',
    }),
    ...recordingArgs,
  },
  cli: {
    format: formatSampleText,
    csv: formatSampleCsv,
  },
  handler: async (session, args) =>
    sampleInstancesHandlerAsync(session, {
      ...toInstanceSelection(args),
      ...(await resolveRecordingAsync(args)),
      properties: parseNameList(args.properties),
      attributes: parseNameList(args.attributes),
    }),
});
