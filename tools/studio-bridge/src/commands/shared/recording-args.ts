import * as fs from 'fs/promises';
import * as path from 'path';
import { arg, type ArgDefinition } from '../framework/arg-builder.js';
import { parseDurationSeconds } from './duration.js';
import type { RecordingOptions } from '../../server/web-socket-protocol.js';
import { invalidInput } from '../../messages/studio-bridge-error.js';

export const DEFAULT_MAX_FRAMES = 300;

export interface RecordingArgs {
  trigger?: string;
  triggerFile?: string;
  duration?: string;
  fps?: number;
  maxFrames?: number;
}

/** What the plugin's `FrameRecorder` takes. */
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

/** What the plugin's `FrameRecorder` takes, for a recording with no set end. */
export type OpenRecordingPayload = Omit<RecordingPayload, 'duration'> & {
  duration?: number;
};

export async function resolveRecordingAsync(
  args: RecordingArgs
): Promise<RecordingPayload> {
  const { duration, ...recording } = await resolveOpenRecordingAsync(args);
  if (duration === undefined) {
    throw invalidInput(
      'No --duration was given, so there is no end to record to.',
      'Add --duration, e.g. --duration 0.8s.'
    );
  }
  return {
    ...recording,
    duration,
    maxFrames: args.maxFrames ?? DEFAULT_MAX_FRAMES,
  };
}

export async function resolveOpenRecordingAsync(
  args: RecordingArgs
): Promise<OpenRecordingPayload> {
  if (args.trigger !== undefined && args.triggerFile !== undefined) {
    throw invalidInput(
      'Both --trigger and --trigger-file were given.',
      'Use one of them.'
    );
  }
  if (args.fps !== undefined && !(args.fps > 0)) {
    throw invalidInput(
      `--fps ${args.fps} is out of range.`,
      'Give a rate above 0, e.g. --fps 30.'
    );
  }
  if (
    args.maxFrames !== undefined &&
    !(Number.isInteger(args.maxFrames) && args.maxFrames > 0)
  ) {
    throw invalidInput(
      `--max-frames ${args.maxFrames} is out of range.`,
      'Give a whole number above 0.'
    );
  }

  let trigger = args.trigger;
  if (args.triggerFile !== undefined) {
    try {
      trigger = await fs.readFile(path.resolve(args.triggerFile), 'utf-8');
    } catch {
      throw invalidInput(
        `Can't read the --trigger-file '${args.triggerFile}'.`,
        'Check the path, then run the command again.'
      );
    }
  }

  return {
    ...(trigger ? { trigger } : {}),
    ...(args.duration !== undefined
      ? { duration: parseDurationSeconds(args.duration, '--duration') }
      : {}),
    ...(args.fps !== undefined ? { fps: args.fps } : {}),
    ...(args.maxFrames !== undefined ? { maxFrames: args.maxFrames } : {}),
  };
}
