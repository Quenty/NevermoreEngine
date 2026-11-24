/**
 * `process launch --from checkout`: builds a deploy target as a
 * `LocalPlaceJobContext` job and opens the result in Studio.
 */

import * as path from 'path';
import { execa } from 'execa';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  BaseReporter,
  CompositeReporter,
  SimpleReporter,
  SpinnerReporter,
  type LiveStateTracker,
  type Reporter,
} from '@quenty/cli-output-helpers/reporting';
import { getApiKeyAsync } from '@quenty/nevermore-cli-helpers';
import {
  LocalPlaceJobContext,
  type BuiltPlace,
  type LocalPlaceJobContextOptions,
} from '@quenty/nevermore-job-helpers';
import {
  OpenCloudPlaceClient,
  RateLimiter,
} from '@quenty/nevermore-job-helpers/open-cloud';
import { createBasePlaceResolver } from '@quenty/nevermore-job-helpers/place';
import { StudioBridgeError } from '../messages/studio-bridge-error.js';
import { type DeployPlace } from './deploy-places.js';
import {
  createStudioLaunchSessionFactory,
  type StudioLaunchSession,
} from './studio-launch-session-factory.js';

export interface LaunchDeployPlaceOptions {
  deployPlace: DeployPlace;
  /** Default: true. */
  mergeBasePlace?: boolean;
  cwd?: string;
  quiet?: boolean;
}

export interface LaunchedDeployPlace {
  rbxlPath: string;
  basePlaceVersion?: number;
}

export async function launchDeployPlaceAsync(
  options: LaunchDeployPlaceOptions
): Promise<LaunchedDeployPlace> {
  const { deployPlace } = options;
  const target = deployPlace.place;
  const packagePath = path.dirname(deployPlace.configPath);
  const packageName = deployPlace.selector;
  const merge = (options.mergeBasePlace ?? true) && target.basePlace != null;

  await _ensureToolAsync('rojo');
  await _ensureToolAsync('lune');

  const reporter = _createReporter(packageName, options.quiet ?? false);
  const contextOptions: LocalPlaceJobContextOptions<StudioLaunchSession> = {
    reporter,
    studio: createStudioLaunchSessionFactory({
      selector: deployPlace.selector,
      cwd: options.cwd,
      placeIdentity: { placeId: target.placeId, universeId: target.universeId },
    }),
  };
  if (merge) {
    const client = new OpenCloudPlaceClient({
      apiKey: await _getApiKeyAsync(deployPlace.selector),
      rateLimiter: new RateLimiter(),
    });
    contextOptions.downloader = client;
    // Opening Studio must not leave a diff, so the lock is never written.
    contextOptions.basePlaceResolver = createBasePlaceResolver(
      client,
      {},
      'readonly'
    );
  }
  const context = new LocalPlaceJobContext(contextOptions);

  const startTime = performance.now();
  await reporter.startAsync();
  reporter.onPackageStart(packageName);

  let builtPlace: BuiltPlace | undefined;
  let session: StudioLaunchSession | undefined;
  let failure: unknown;
  try {
    try {
      builtPlace = await context.buildPlaceAsync({
        target,
        packagePath,
        packageName,
        deferBasePlaceMerge: !merge,
      });
    } catch (err) {
      throw _buildFailedError(deployPlace.selector, err);
    }
    const deployment = await context.deployBuiltPlaceAsync({
      builtPlace,
      packageName,
      packagePath,
    });
    session = deployment.session;
    await context.releaseAsync(deployment);
  } catch (err) {
    failure = err;
  } finally {
    try {
      await context.disposeAsync();
    } catch (err) {
      failure ??= err;
    }
  }

  reporter.onPackageResult({
    packageName,
    success: failure === undefined,
    logs: '',
    durationMs: performance.now() - startTime,
    error: failure === undefined ? undefined : _firstLine(failure),
  });
  await reporter.stopAsync();

  if (failure !== undefined || !session) {
    throw failure;
  }
  return {
    rbxlPath: session.placePath,
    basePlaceVersion: builtPlace?.basePlaceVersion,
  };
}

/** Build failures usually say what to do in their first line, so it is kept. */
function _buildFailedError(selector: string, err: unknown): StudioBridgeError {
  if (err instanceof StudioBridgeError) {
    return err;
  }
  return new StudioBridgeError({
    code: 'PLACE_BUILD_FAILED',
    message: `Could not build '${selector}' from this checkout: ${_firstLine(
      err
    )}`,
    fix: OutputHelper.isVerbose()
      ? undefined
      : 'Run again with --verbose for the full error.',
    cause: err,
  });
}

async function _ensureToolAsync(tool: 'rojo' | 'lune'): Promise<void> {
  try {
    await execa(tool, ['--version']);
  } catch (err) {
    throw new StudioBridgeError({
      code: 'TOOLCHAIN_MISSING',
      message: `Building a place from this checkout needs ${tool}, which was not found.`,
      fix: 'Run `aftman install` from the repo root.',
      cause: err,
    });
  }
}

async function _getApiKeyAsync(selector: string): Promise<string> {
  try {
    // Never prompts: agents run this without a TTY.
    return await getApiKeyAsync({ yes: true });
  } catch (err) {
    throw new StudioBridgeError({
      code: 'MISSING_API_KEY',
      message: `'${selector}' has a base place, and downloading it needs an Open Cloud API key.`,
      fix: 'Run `nevermore login`, set ROBLOX_OPEN_CLOUD_API_KEY, or pass --no-base-place.',
      cause: err,
    });
  }
}

function _createReporter(packageName: string, quiet: boolean): Reporter {
  if (quiet) {
    return new BaseReporter();
  }
  const useSpinner = !!process.stdout.isTTY && !OutputHelper.isVerbose();
  return new CompositeReporter([packageName], (state: LiveStateTracker) => [
    useSpinner
      ? new SpinnerReporter(state, { showLogs: false, actionVerb: 'Opening' })
      : new SimpleReporter(state, {
          alwaysShowLogs: false,
          successMessage: 'Studio opened on the built place.',
          failureMessage: 'Could not open the built place in Studio.',
        }),
  ]);
}

function _firstLine(err: unknown): string {
  const message = err instanceof Error ? err.message : String(err);
  return message.split('\n')[0];
}
