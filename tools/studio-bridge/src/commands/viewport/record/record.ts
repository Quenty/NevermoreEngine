/**
 * `viewport record` — capture the Studio viewport over a window of frames,
 * optionally after running a trigger, and write the frames, a manifest and a
 * contact sheet into a directory.
 */

import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  formatJson,
  type OutputFile,
} from '@quenty/cli-output-helpers/reporting';
import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession } from '../../../bridge/index.js';
import type {
  RecordedViewportFrame,
  RecordingClock,
  SkippedViewportFrame,
  ViewportReadOptions,
} from '../../../server/web-socket-protocol.js';
import { pngToRgba } from '../../png-to-rgba.js';
import { rgbaToPng } from '../../rgba-to-png.js';
import {
  recordingArgs,
  resolveRecordingAsync,
  type RecordingArgs,
  type RecordingPayload,
} from '../../shared/recording-args.js';
import {
  toViewportReadOptions,
  viewportArgs,
  type ViewportArgs,
} from '../viewport-args.js';
import {
  buildContactSheet,
  formatFrameLabel,
  formatTimeLabel,
  pickEvenlySpaced,
} from './contact-sheet.js';

const DEFAULT_SHEET_FRAMES = 16;

export type { SkippedViewportFrame };

export interface RecordedFrame {
  index: number;
  /** Seconds of frame time since frame 0, when this frame was captured. */
  t: number;
  /** Which frame since frame 0 it was. */
  frame: number;
  /** File name in the output directory, e.g. `frame-000.png`. */
  file: string;
  width: number;
  height: number;
  /** The PNG, base64-encoded. Left out of the manifest. */
  data: string;
}

export interface RecordResult {
  /** The captures CaptureService made, at the times they show. */
  frames: RecordedFrame[];
  /** Captures asked for, one per recorded frame; CaptureService drops most. */
  requested: number;
  /** Captures made and read, the length of `frames`. */
  captured: number;
  /** Captures made but not read, with why. Absent when there were none. */
  skipped?: SkippedViewportFrame[];
  elapsed: number;
  /** Captures per second actually achieved. */
  captureRate: number;
  requestedFps?: number;
  truncated: boolean;
  clock: RecordingClock;
  /** The contact sheet PNG, base64-encoded. Absent with `--sheet-frames 0`. */
  sheet?: string;
  summary: string;
}

export interface RecordOptions extends RecordingPayload, ViewportReadOptions {
  /** Frames on the contact sheet (default 16, 0 for none). */
  sheetFrames?: number;
}

export async function recordViewportHandlerAsync(
  session: BridgeSession,
  options: RecordOptions
): Promise<RecordResult> {
  const { sheetFrames = DEFAULT_SHEET_FRAMES, ...payload } = options;
  if (!Number.isInteger(sheetFrames) || sheetFrames < 0) {
    throw new Error('--sheet-frames must be a whole number, 0 or more');
  }
  if (session.context === 'server') {
    throw new Error(
      "A playtest's server renders nothing to record. Record Edit, or the playtest's client with --context client"
    );
  }

  const result = await session.recordViewportAsync(payload);

  const frames = result.frames.map((captured, index) => ({
    index,
    t: captured.t,
    frame: captured.frame,
    file: `frame-${String(index).padStart(3, '0')}.png`,
    width: captured.width,
    height: captured.height,
    data: toPngBase64(captured),
  }));

  const span =
    frames.length > 1 ? frames[frames.length - 1].t - frames[0].t : 0;
  const captureRate = span > 0 ? (frames.length - 1) / span : 0;
  const skipped = result.skipped.length > 0 ? result.skipped : undefined;

  const stats = {
    captured: frames.length,
    requested: result.requested,
    skipped: result.skipped.length,
    elapsed: result.elapsed,
    captureRate,
  };
  const sheet = buildSheet(
    result.frames,
    pickEvenlySpaced(frames.length, sheetFrames),
    formatSheetHeader(stats)
  );

  return {
    frames,
    requested: result.requested,
    captured: frames.length,
    ...(skipped ? { skipped } : {}),
    elapsed: result.elapsed,
    captureRate,
    ...(options.fps !== undefined ? { requestedFps: options.fps } : {}),
    truncated: result.truncated,
    clock: result.clock,
    ...(sheet ? { sheet } : {}),
    summary: summarize(stats, {
      requestedFps: options.fps,
      truncated: result.truncated,
    }),
  };
}

/** The frame as a base64 PNG, encoding it here when Studio sent raw RGBA. */
function toPngBase64(captured: RecordedViewportFrame): string {
  if (captured.format === 'png') return captured.data;
  return rgbaToPng(
    Buffer.from(captured.data, 'base64'),
    captured.width,
    captured.height
  ).toString('base64');
}

/** The frame's pixels, decoding its PNG when Studio sent one. */
function toRgba(captured: RecordedViewportFrame): Buffer {
  const bytes = Buffer.from(captured.data, 'base64');
  return captured.format === 'png' ? pngToRgba(bytes).rgba : bytes;
}

/** Builds the contact sheet from the frames at `indices`, decoding only those. */
function buildSheet(
  captured: RecordedViewportFrame[],
  indices: number[],
  header: string
): string | undefined {
  if (indices.length === 0) return undefined;

  const image = buildContactSheet(
    indices.map((i) => ({
      rgba: toRgba(captured[i]),
      width: captured[i].width,
      height: captured[i].height,
      label: formatFrameLabel(captured[i].t, captured[i].frame),
    })),
    { header }
  );
  return rgbaToPng(image.rgba, image.width, image.height).toString('base64');
}

interface RecordStats {
  captured: number;
  requested: number;
  skipped: number;
  elapsed: number;
  captureRate: number;
}

/** E.g. `6 of 19 captured · 5.0/s · 1.201s`. */
export function formatSheetHeader(stats: RecordStats): string {
  const parts = [
    `${stats.captured} of ${stats.requested} captured`,
    `${stats.captureRate.toFixed(1)}/s`,
    formatTimeLabel(stats.elapsed),
  ];
  if (stats.skipped > 0) parts.push(`${stats.skipped} skipped`);
  return parts.join(' · ');
}

function summarize(
  stats: RecordStats,
  details: { requestedFps?: number; truncated: boolean }
): string {
  const notes = [`${stats.captureRate.toFixed(1)}/s`];
  if (details.requestedFps !== undefined) {
    notes.push(`--fps ${details.requestedFps}`);
  }
  if (details.truncated) notes.push('stopped at --max-frames');
  if (stats.skipped > 0) notes.push(`${stats.skipped} could not be read`);
  return `Captured ${stats.captured} of ${
    stats.requested
  } requested frames over ${formatTimeLabel(stats.elapsed)} (${notes.join(
    ', '
  )})`;
}

/** Rounds seconds and rates to milliseconds for the manifest. */
function round3(value: number): number {
  return Math.round(value * 1000) / 1000;
}

/** The result as written to manifest.json and printed by `--format json`. */
export function toManifest(result: RecordResult): Record<string, unknown> {
  const { frames, sheet, skipped, ...rest } = result;
  return {
    ...rest,
    elapsed: round3(result.elapsed),
    captureRate: round3(result.captureRate),
    frames: frames.map(({ data: _data, ...frame }) => ({
      ...frame,
      t: round3(frame.t),
    })),
    ...(skipped
      ? { skipped: skipped.map((s) => ({ ...s, t: round3(s.t) })) }
      : {}),
    ...(sheet ? { sheet: 'sheet.png' } : {}),
  };
}

export function toOutputFiles(result: RecordResult): OutputFile[] {
  return [
    ...result.frames.map((frame) => ({
      path: frame.file,
      data: Buffer.from(frame.data, 'base64'),
    })),
    ...(result.sheet
      ? [{ path: 'sheet.png', data: Buffer.from(result.sheet, 'base64') }]
      : []),
    {
      path: 'manifest.json',
      data: formatJson(toManifest(result), { pretty: true }) + '\n',
    },
  ];
}

export function formatRecordText(result: RecordResult): string {
  if (result.frames.length === 0) return result.summary;
  const times = result.frames.map((f) => formatTimeLabel(f.t)).join(' ');
  return `${result.summary}\n${OutputHelper.formatDim(`at ${times}`)}`;
}

interface RecordArgs extends RecordingArgs, ViewportArgs {
  sheetFrames?: number;
}

export const recordCommand = defineCommand<RecordArgs, RecordResult>({
  group: 'viewport',
  name: 'record',
  description:
    'Capture the viewport over a window of frames, writing the frames, manifest.json and sheet.png into the -o directory',
  category: 'execution',
  // A trigger runs arbitrary code
  safety: 'mutate',
  changesDataModel: true,
  scope: 'session',
  args: {
    ...recordingArgs,
    ...viewportArgs,
    sheetFrames: arg.option({
      description: `Frames on the contact sheet, spread evenly (default: ${DEFAULT_SHEET_FRAMES}, 0 for none)`,
      type: 'number',
    }),
  },
  cli: {
    format: formatRecordText,
    json: (result) =>
      formatJson(toManifest(result), { pretty: process.stdout.isTTY }),
    files: toOutputFiles,
  },
  handler: async (session, args) =>
    recordViewportHandlerAsync(session, {
      ...(await resolveRecordingAsync(args)),
      ...toViewportReadOptions(args),
      ...(args.sheetFrames !== undefined
        ? { sheetFrames: args.sheetFrames }
        : {}),
    }),
});
