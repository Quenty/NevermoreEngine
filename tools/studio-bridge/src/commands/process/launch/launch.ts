/**
 * `process launch` — launch Roblox Studio, optionally with a place file, a
 * cloud place, or a target from the nearest `deploy.nevermore.json`.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import {
  formatTargetSelector,
  loadDeployConfigAsync,
  parseTargetSelector,
  resolveDefaultTargetName,
  resolveDeployTargetPlaces,
  type DeployTarget,
} from '@quenty/nevermore-deploy';
import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { launchStudioAsync } from '../../../process/studio-process-manager.js';

const DEPLOY_CONFIG_FILE_NAME = 'deploy.nevermore.json';

export interface LaunchOptions {
  placePath?: string;
  placeId?: number;
  universeId?: number;
  /** A `deploy.nevermore.json` target, e.g. `test` or `integration.places.hub`. */
  target?: string;
  /** Where to start looking for `deploy.nevermore.json`. Default: the current directory. */
  cwd?: string;
}

export interface LaunchResult {
  launched: boolean;
  /** The `deploy.nevermore.json` target that was opened, if any. */
  target?: string;
  placeId?: number;
  universeId?: number;
  summary: string;
}

export interface DeployPlace {
  selector: string;
  place: DeployTarget;
  configPath: string;
}

export async function launchHandlerAsync(
  options: LaunchOptions = {}
): Promise<LaunchResult> {
  const hasExplicitPlace =
    options.placePath !== undefined || options.placeId !== undefined;
  if (hasExplicitPlace && options.target !== undefined) {
    throw new Error(
      `Pass a deploy target or --place / --place-id, not both (got target '${options.target}')`
    );
  }

  const deployPlace = hasExplicitPlace
    ? undefined
    : await resolveDeployPlaceAsync(
        options.cwd ?? process.cwd(),
        options.target
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
      target: deployPlace.selector,
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

/**
 * The place a `deploy.nevermore.json` target names, from the config nearest
 * `cwd`. Without `target`, uses the config's default target. Undefined when no
 * config is found and no target was asked for.
 */
export async function resolveDeployPlaceAsync(
  cwd: string,
  target?: string
): Promise<DeployPlace | undefined> {
  const configPath = await findDeployConfigPathAsync(cwd);
  if (!configPath) {
    if (target !== undefined) {
      throw new Error(
        `No ${DEPLOY_CONFIG_FILE_NAME} in ${cwd} or its parents to find target '${target}' in`
      );
    }
    return undefined;
  }

  const config = await loadDeployConfigAsync(configPath);
  const selector = target ?? resolveDefaultTargetName(config);
  const places = resolveDeployTargetPlaces(config, selector);
  if (places.length > 1) {
    const { targetName } = parseTargetSelector(selector);
    const choices = places
      .map((place) =>
        place.name
          ? `  - ${formatTargetSelector({ targetName, placeName: place.name })}`
          : `  - place ${place.placeId}`
      )
      .join('\n');
    throw new Error(
      `Target '${targetName}' has ${places.length} places. Pick one:\n${choices}`
    );
  }

  return { selector, place: places[0], configPath };
}

async function findDeployConfigPathAsync(
  startDir: string
): Promise<string | undefined> {
  let current = path.resolve(startDir);
  while (true) {
    const candidate = path.join(current, DEPLOY_CONFIG_FILE_NAME);
    try {
      await fs.access(candidate);
      return candidate;
    } catch {
      // Not here, keep walking up
    }

    const parent = path.dirname(current);
    if (parent === current) {
      return undefined;
    }
    current = parent;
  }
}

interface LaunchArgs {
  target?: string;
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
    target: arg.positional({
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
      target: args.target,
      placePath: args.place,
      placeId: args.placeId,
      universeId: args.universeId,
    }),
});
