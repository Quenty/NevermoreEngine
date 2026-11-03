/**
 * `process launch` — launch Roblox Studio, optionally with a place file, a
 * cloud place, or a target from the nearest `deploy.nevermore.json`.
 */

import * as path from 'path';
import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { launchStudioAsync } from '../../../process/studio-process-manager.js';
import {
  DEPLOY_CONFIG_FILE_NAME,
  resolveDeployPlaceAsync,
} from '../../../deploy/deploy-places.js';

export interface LaunchOptions {
  placePath?: string;
  placeId?: number;
  universeId?: number;
  /** A `deploy.nevermore.json` target, e.g. `test` or `integration.places.hub`. */
  deployTarget?: string;
  /** Where to start looking for `deploy.nevermore.json`. Default: the current directory. */
  cwd?: string;
}

export interface LaunchResult {
  launched: boolean;
  /** The `deploy.nevermore.json` target that was opened, if any. */
  deployTarget?: string;
  placeId?: number;
  universeId?: number;
  summary: string;
}

export async function launchHandlerAsync(
  options: LaunchOptions = {}
): Promise<LaunchResult> {
  const hasExplicitPlace =
    options.placePath !== undefined || options.placeId !== undefined;
  if (hasExplicitPlace && options.deployTarget !== undefined) {
    throw new Error(
      `Pass a deploy target or --place / --place-id, not both (got '${options.deployTarget}')`
    );
  }

  const deployPlace = hasExplicitPlace
    ? undefined
    : await resolveDeployPlaceAsync(
        options.cwd ?? process.cwd(),
        options.deployTarget
      );
  if (deployPlace) {
    const { placeId, universeId } = deployPlace.place;
    await launchStudioAsync({ placeId, universeId });
    const configDir = path.relative(
      options.cwd ?? process.cwd(),
      path.dirname(deployPlace.configPath)
    );
    return {
      launched: true,
      deployTarget: deployPlace.selector,
      placeId,
      universeId,
      summary: `Studio launched with '${
        deployPlace.selector
      }' (place ${placeId}, universe ${universeId}) from ${path.join(
        configDir,
        DEPLOY_CONFIG_FILE_NAME
      )}`,
    };
  }

  const { placePath, placeId, universeId } = options;
  await launchStudioAsync({ placePath, placeId, universeId });
  const opened =
    placeId != null
      ? `place ${placeId}${
          universeId != null ? ` (universe ${universeId})` : ''
        }`
      : placePath;
  return {
    launched: true,
    placeId,
    universeId,
    summary: `Studio launched${opened ? ` with ${opened}` : ''}`,
  };
}

interface LaunchArgs {
  deployTarget?: string;
  place?: string;
  placeId?: number;
  universeId?: number;
}

export const launchCommand = defineCommand<LaunchArgs, LaunchResult>({
  group: 'process',
  name: 'launch',
  description:
    "Launch Roblox Studio, by default with the place of the nearest deploy.nevermore.json's default target",
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {
    deployTarget: arg.positional({
      description:
        'deploy.nevermore.json target to open, e.g. test or integration.places.hub (default: its default target)',
      required: false,
    }),
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
      deployTarget: args.deployTarget,
      placePath: args.place,
      placeId: args.placeId,
      universeId: args.universeId,
    }),
});
