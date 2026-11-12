import { arg, type ArgDefinition } from '../framework/arg-builder.js';
import type { BridgeConnection, BridgeSession } from '../../bridge/index.js';
import type {
  ViewportReadOptions,
  ViewportRegion,
} from '../../server/web-socket-protocol.js';
import {
  invalidInput,
  StudioBridgeError,
} from '../../messages/studio-bridge-error.js';

export interface ViewportArgs {
  region?: string;
  scale?: number;
}

export const viewportArgs: Record<keyof ViewportArgs, ArgDefinition> = {
  region: arg.option({
    description:
      'Crop to x,y,width,height in viewport pixels (default: the whole viewport)',
  }),
  scale: arg.option({
    description: 'Scale the image by this factor after cropping, up to 1',
    type: 'number',
  }),
};

export type CaptureSource = 'captureService' | 'studioMcp';

export function getPlaytestMode(
  session: BridgeSession,
  connection?: BridgeConnection
): 'edit' | 'play' | 'run' {
  const state =
    connection
      ?.listSessions()
      .find((s) => s.sessionId === session.info.sessionId)?.state ??
    session.info.state;
  if (state === 'Run') return 'run';
  if (state === 'Play' || session.context !== 'edit') return 'play';
  return 'edit';
}

export function resolveCaptureSource(
  session: BridgeSession,
  connection?: BridgeConnection
): CaptureSource {
  const mode = getPlaytestMode(session, connection);
  if (mode === 'run') {
    throw new StudioBridgeError({
      code: 'VIEWPORT_UNAVAILABLE',
      message:
        "Can't capture a Run-mode playtest, since nothing renders it without a client.",
      fix: "Run 'studio-bridge playtest restart --mode play', or stop the playtest to capture Edit.",
    });
  }
  return mode === 'play' ? 'studioMcp' : 'captureService';
}

export function assertCanRecord(
  session: BridgeSession,
  connection?: BridgeConnection
): void {
  const mode = getPlaytestMode(session, connection);
  if (mode === 'run') {
    throw new StudioBridgeError({
      code: 'VIEWPORT_UNAVAILABLE',
      message:
        "Can't record a Run-mode playtest, since nothing renders it without a client.",
      fix: 'Stop the playtest to record Edit.',
    });
  }
  if (mode === 'play') {
    throw new StudioBridgeError({
      code: 'VIEWPORT_UNAVAILABLE',
      message:
        "Can't record during a playtest, since Studio only captures one at about 5 frames a second, without frame timing.",
      fix: "Take single frames with 'viewport screenshot', or stop the playtest to record Edit.",
    });
  }
}

export function parseRegion(value: string): ViewportRegion {
  const parts = value.split(',').map((part) => Number(part.trim()));
  if (
    parts.length !== 4 ||
    parts.some((n) => !Number.isFinite(n)) ||
    parts[0] < 0 ||
    parts[1] < 0 ||
    parts[2] <= 0 ||
    parts[3] <= 0
  ) {
    throw invalidInput(
      `Can't read --region '${value}'.`,
      'Give x,y,width,height in pixels, e.g. 0,0,640,360.'
    );
  }
  return parts as ViewportRegion;
}

export function toViewportReadOptions(args: ViewportArgs): ViewportReadOptions {
  if (args.scale !== undefined && !(args.scale > 0 && args.scale <= 1)) {
    throw invalidInput(
      `--scale ${args.scale} is out of range.`,
      'Give a scale above 0 and at most 1, e.g. 0.5.'
    );
  }
  return {
    ...(args.region !== undefined ? { region: parseRegion(args.region) } : {}),
    ...(args.scale !== undefined ? { scale: args.scale } : {}),
  };
}
