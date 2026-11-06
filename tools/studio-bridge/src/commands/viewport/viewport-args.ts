/**
 * `--region` and `--scale`, shared by `viewport screenshot` and `viewport
 * record`. Studio side, both crop and scale through the `viewport-capture`
 * library before reading pixels.
 */

import { arg, type ArgDefinition } from '../framework/arg-builder.js';
import type {
  ViewportReadOptions,
  ViewportRegion,
} from '../../server/web-socket-protocol.js';

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

/** Parses `x,y,width,height`. */
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
    throw new Error(
      `Can't read --region '${value}'. Give x,y,width,height in pixels, e.g. 0,0,640,360`
    );
  }
  return parts as ViewportRegion;
}

/** Turns the parsed args into what the plugin's `viewport-capture` takes. */
export function toViewportReadOptions(args: ViewportArgs): ViewportReadOptions {
  if (args.scale !== undefined && !(args.scale > 0 && args.scale <= 1)) {
    throw new Error('--scale must be above 0 and at most 1');
  }
  return {
    ...(args.region !== undefined ? { region: parseRegion(args.region) } : {}),
    ...(args.scale !== undefined ? { scale: args.scale } : {}),
  };
}
