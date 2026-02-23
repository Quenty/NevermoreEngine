/**
 * Handler for the `launch` command. Launches Roblox Studio, optionally
 * with a specific place file.
 */

import { launchStudioAsync } from '../process/studio-process-manager.js';

export interface LaunchOptions {
  placePath?: string;
}

export interface LaunchResult {
  launched: boolean;
  summary: string;
}

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
