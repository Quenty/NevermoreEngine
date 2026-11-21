/**
 * `process launch` — launch Roblox Studio, optionally with a place file, a
 * cloud place, or a target from the nearest `deploy.nevermore.json`.
 */

import * as path from 'path';
import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { launchAndRecordStudioAsync } from '../../../process/launch-and-record-studio.js';
import {
  DEPLOY_CONFIG_FILE_NAME,
  resolveDeployPlaceAsync,
} from '../../../deploy/deploy-places.js';
import { launchDeployPlaceAsync } from '../../../deploy/launch-deploy-place.js';
import { invalidInput } from '../../../messages/studio-bridge-error.js';
import { isJsonOutputEnabled } from '../../../cli/cli-output-context.js';

const BASEPLATE_TEMPLATE = { placeId: 95206881, universeId: 28220420 };

export const LAUNCH_SOURCES = ['studio', 'checkout'] as const;
export type LaunchSource = typeof LAUNCH_SOURCES[number];

export interface LaunchOptions {
  placePath?: string;
  placeId?: number;
  universeId?: number;
  /** A `deploy.nevermore.json` target, e.g. `test` or `integration.places.hub`. */
  deployTarget?: string;
  /** Where to start looking for `deploy.nevermore.json`. Default: the current directory. */
  cwd?: string;
  /** Default: `studio`. */
  from?: LaunchSource;
  /** For `--from checkout`. Default: true. */
  mergeBasePlace?: boolean;
}

export interface LaunchResult {
  launched: boolean;
  /** The `deploy.nevermore.json` target that was opened, if any. */
  deployTarget?: string;
  from?: LaunchSource;
  placeId?: number;
  universeId?: number;
  /** For `--from checkout`. */
  placePath?: string;
  basePlaceVersion?: number;
  summary: string;
}

export async function launchHandlerAsync(
  options: LaunchOptions = {}
): Promise<LaunchResult> {
  const hasExplicitPlace =
    options.placePath !== undefined || options.placeId !== undefined;
  if (hasExplicitPlace && options.deployTarget !== undefined) {
    throw invalidInput(
      `Both a deploy target ('${options.deployTarget}') and --place or --place-id were given.`,
      'Use one of them.'
    );
  }
  const targetFlags = _targetFlags(options);
  if (hasExplicitPlace && targetFlags.length > 0) {
    throw invalidInput(
      `${_listFlags(targetFlags)} ${
        targetFlags.length === 1 ? 'applies' : 'apply'
      } to a deploy target, not to --place or --place-id.`,
      `Drop ${_listFlags(targetFlags)}.`
    );
  }
  if (options.mergeBasePlace === false && options.from !== 'checkout') {
    throw invalidInput(
      '--no-base-place applies to --from checkout, which builds the place.',
      'Add --from checkout, or drop --no-base-place.'
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
    const fromConfig = path.join(
      path.relative(
        options.cwd ?? process.cwd(),
        path.dirname(deployPlace.configPath)
      ),
      DEPLOY_CONFIG_FILE_NAME
    );

    if (options.from !== 'checkout') {
      await launchAndRecordStudioAsync(
        { placeId, universeId },
        {
          opened: `'${deployPlace.selector}' (place ${placeId})`,
          deployTarget: deployPlace.selector,
        },
        options.cwd
      );
      return {
        launched: true,
        deployTarget: deployPlace.selector,
        from: 'studio',
        placeId,
        universeId,
        summary: `Studio launched with '${deployPlace.selector}' (place ${placeId}, universe ${universeId}) from ${fromConfig}`,
      };
    }

    const built = await launchDeployPlaceAsync({
      deployPlace,
      mergeBasePlace: options.mergeBasePlace,
      cwd: options.cwd,
      quiet: isJsonOutputEnabled(),
    });
    const onBase =
      built.basePlaceVersion !== undefined
        ? ` on base place v${built.basePlaceVersion}`
        : '';
    return {
      launched: true,
      deployTarget: deployPlace.selector,
      from: 'checkout',
      placeId,
      universeId,
      placePath: built.rbxlPath,
      basePlaceVersion: built.basePlaceVersion,
      summary: `Studio launched with '${deployPlace.selector}' built from this checkout${onBase} (${fromConfig}). Saving it does not change place ${placeId}.`,
    };
  }

  if (!hasExplicitPlace) {
    if (targetFlags.length > 0) {
      throw invalidInput(
        `${_listFlags(targetFlags)} ${
          targetFlags.length === 1 ? 'opens' : 'open'
        } a deploy target, and there is no ${DEPLOY_CONFIG_FILE_NAME} here or above.`,
        `Run it in a package or game folder, or drop ${_listFlags(
          targetFlags
        )}.`
      );
    }
    await launchAndRecordStudioAsync(
      BASEPLATE_TEMPLATE,
      { opened: 'a new Baseplate' },
      options.cwd
    );
    return {
      launched: true,
      summary: 'Studio launched with a new Baseplate',
    };
  }

  const { placePath, placeId, universeId } = options;
  await launchAndRecordStudioAsync(
    { placePath, placeId, universeId },
    { opened: placeId != null ? `place ${placeId}` : placePath ?? 'Studio' },
    options.cwd
  );
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

function _targetFlags(options: LaunchOptions): string[] {
  const flags: string[] = [];
  if (options.from !== undefined) flags.push(`--from ${options.from}`);
  if (options.mergeBasePlace === false) flags.push('--no-base-place');
  return flags;
}

function _listFlags(flags: string[]): string {
  if (flags.length <= 1) return flags.join('');
  return `${flags.slice(0, -1).join(', ')} and ${flags[flags.length - 1]}`;
}

interface LaunchArgs {
  deployTarget?: string;
  place?: string;
  placeId?: number;
  universeId?: number;
  from?: LaunchSource;
  basePlace?: boolean;
}

export const launchCommand = defineCommand<LaunchArgs, LaunchResult>({
  group: 'process',
  name: 'launch',
  description:
    "Launch Roblox Studio with the nearest deploy.nevermore.json's default target, or else a new Baseplate",
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
    from: arg.option({
      description:
        "Where the target's place comes from: studio, the place on Roblox (default), or checkout, " +
        'a throwaway build of this checkout',
      choices: LAUNCH_SOURCES,
    }),
    basePlace: arg.flag({
      description:
        "With --from checkout, merge the target's base place under the code. --no-base-place builds the code alone",
      default: true,
    }),
  },
  handler: async (args) =>
    launchHandlerAsync({
      deployTarget: args.deployTarget,
      placePath: args.place,
      placeId: args.placeId,
      universeId: args.universeId,
      from: args.from,
      mergeBasePlace: args.basePlace,
    }),
});
