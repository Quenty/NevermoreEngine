/**
 * `process launch` — launch Roblox Studio, optionally with a place file.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { launchStudioAsync } from '../../../process/studio-process-manager.js';

export interface LaunchOptions {
  placePath?: string;
  placeId?: number;
  universeId?: number;
}

export interface LaunchResult {
  launched: boolean;
  summary: string;
}

export async function launchHandlerAsync(
  options: LaunchOptions = {}
): Promise<LaunchResult> {
  await launchStudioAsync(options);
  const target =
    options.placeId != null
      ? `place ${options.placeId}${
          options.universeId != null ? ` (universe ${options.universeId})` : ''
        }`
      : options.placePath;
  return {
    launched: true,
    summary: `Studio launched${target ? ` with ${target}` : ''}`,
  };
}

interface LaunchArgs {
  place?: string;
  placeId?: number;
  universeId?: number;
}

export const launchCommand = defineCommand<LaunchArgs, LaunchResult>({
  group: 'process',
  name: 'launch',
  description: 'Launch Roblox Studio',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {
    place: arg.option({ description: 'Path to a .rbxl place file' }),
    placeId: arg.option({
      description:
        'Cloud place id to open in Studio (edit mode, via the EditPlace deep-link)',
      type: 'number',
    }),
    universeId: arg.option({
      description:
        'Cloud universe id for the place (recommended with --place-id)',
      type: 'number',
    }),
  },
  handler: async (args) =>
    launchHandlerAsync({
      placePath: args.place,
      placeId: args.placeId,
      universeId: args.universeId,
    }),
});
