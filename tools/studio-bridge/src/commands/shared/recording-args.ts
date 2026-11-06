/**
 * Args shared by the commands that record a window of frames in Studio
 * (`explorer sample`, `viewport record`), so both declare and read them the
 * same way. Studio side, both run on the `frame-recorder` library.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { arg, type ArgDefinition } from '../framework/arg-builder.js';
import { parseDurationSeconds } from './duration.js';
import type { RecordingOptions } from '../../server/web-socket-protocol.js';

export const DEFAULT_MAX_FRAMES = 300;

export interface RecordingArgs {
  trigger?: string;
  triggerFile?: string;
  duration?: string;
  fps?: number;
  maxFrames?: number;
}

/** What the plugin's `frame-recorder` takes. */
export type RecordingPayload = RecordingOptions;

export const recordingArgs: Record<keyof RecordingArgs, ArgDefinition> = {
  trigger: arg.option({
    description:
      'Luau to run at the start of the recording, in frame 0 (e.g. start a tween). Omit to record passively',
  }),
  triggerFile: arg.option({
    description: 'Path to a Luau file to run as the trigger',
  }),
  duration: arg.option({
    description:
      'How long to record: 800ms, 0.8s, 2s (a bare number is seconds)',
    required: true,
  }),
  fps: arg.option({
    description: 'Frames to record per second (default: every frame)',
    type: 'number',
  }),
  maxFrames: arg.option({
    description: `Stop after recording this many frames (default: ${DEFAULT_MAX_FRAMES})`,
    type: 'number',
  }),
};

/** Reads the trigger file, parses the duration, and checks the numbers. */
export async function resolveRecordingAsync(
  args: RecordingArgs
): Promise<RecordingPayload> {
  if (args.duration === undefined) {
    throw new Error('Give a --duration to record for, e.g. --duration 0.8s');
  }
  if (args.trigger !== undefined && args.triggerFile !== undefined) {
    throw new Error('Give --trigger or --trigger-file, not both');
  }
  if (args.fps !== undefined && !(args.fps > 0)) {
    throw new Error('--fps must be above 0');
  }
  if (
    args.maxFrames !== undefined &&
    !(Number.isInteger(args.maxFrames) && args.maxFrames > 0)
  ) {
    throw new Error('--max-frames must be a whole number above 0');
  }

  let trigger = args.trigger;
  if (args.triggerFile !== undefined) {
    try {
      trigger = await fs.readFile(path.resolve(args.triggerFile), 'utf-8');
    } catch {
      throw new Error(`Trigger file not found: ${args.triggerFile}`);
    }
  }

  return {
    ...(trigger ? { trigger } : {}),
    duration: parseDurationSeconds(args.duration, '--duration'),
    ...(args.fps !== undefined ? { fps: args.fps } : {}),
    maxFrames: args.maxFrames ?? DEFAULT_MAX_FRAMES,
  };
}
