/**
 * `process launch` — launch Roblox Studio, optionally with a place file.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { launchStudioAsync } from '../../../process/studio-process-manager.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface LaunchOptions {
  placePath?: string;
}

export interface LaunchResult {
  launched: boolean;
  summary: string;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/**
 * Launch Roblox Studio, optionally with a specific place file.
 */
export async function launchHandlerAsync(
  options: LaunchOptions = {},
): Promise<LaunchResult> {
  await launchStudioAsync(options.placePath ?? '');
  return {
    launched: true,
    summary: `Studio launched${options.placePath ? ` with ${options.placePath}` : ''}`,
  };
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

interface LaunchArgs {
  place?: string;
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
  },
  handler: async (args) => launchHandlerAsync({ placePath: args.place }),
});
