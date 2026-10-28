/**
 * Finds the places of the nearest `deploy.nevermore.json`, so commands run in
 * a package or game folder can open or pick that project's Studio.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import {
  formatTargetSelector,
  loadDeployConfigAsync,
  parseTargetSelector,
  resolveDefaultTargetName,
  resolveDeployTargetPlaces,
  type DeployConfig,
  type DeployTarget,
} from '@quenty/nevermore-deploy';
import type { BridgeConnection, InstanceInfo } from '../bridge/index.js';

export const DEPLOY_CONFIG_FILE_NAME = 'deploy.nevermore.json';

const PLACE_ID_QUERY_TIMEOUT_MS = 3_000;

export interface DeployPlace {
  /** The target selector naming this place, e.g. `test` or `integration.places.hub`. */
  selector: string;
  place: DeployTarget;
  configPath: string;
}

/**
 * The nearest `deploy.nevermore.json` at or above `startDir` that has targets.
 * A repo root's config can hold only a shared `universeId`, so it is skipped.
 */
export async function findDeployConfigPathAsync(
  startDir: string
): Promise<string | undefined> {
  let current = path.resolve(startDir);
  while (true) {
    const candidate = path.join(current, DEPLOY_CONFIG_FILE_NAME);
    if (await hasTargetsAsync(candidate)) {
      return candidate;
    }

    const parent = path.dirname(current);
    if (parent === current) {
      return undefined;
    }
    current = parent;
  }
}

async function hasTargetsAsync(configPath: string): Promise<boolean> {
  let content: string;
  try {
    content = await fs.readFile(configPath, 'utf-8');
  } catch {
    return false;
  }
  try {
    return 'targets' in (JSON.parse(content) as object);
  } catch {
    // Loading it reports the parse error
    return true;
  }
}

/**
 * The place a target names, from the config nearest `cwd`. Without `target`,
 * uses the config's default target. Undefined when no config is found and no
 * target was asked for.
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
  let selector = target;
  if (selector === undefined) {
    try {
      selector = resolveDefaultTargetName(config);
    } catch {
      throw new Error(
        `${configPath} has several targets and no default. Name one: ${Object.keys(
          config.targets
        ).join(', ')}`
      );
    }
  }
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

/** Every place in `config`, each under the selector that names it. */
export function listDeployPlaces(
  config: DeployConfig,
  configPath: string
): DeployPlace[] {
  return Object.keys(config.targets).flatMap((targetName) => {
    const places = resolveDeployTargetPlaces(config, targetName);
    return places.map((place) => ({
      selector:
        places.length > 1 && place.name
          ? formatTargetSelector({ targetName, placeName: place.name })
          : targetName,
      place,
      configPath,
    }));
  });
}

export interface FolderInstance {
  instanceId: string;
  deployPlace: DeployPlace;
}

/**
 * The one connected Studio that has a place of the nearest config open, when
 * several Studios are connected and exactly one does. Undefined otherwise,
 * including when the config can't be read.
 */
export async function tryFindFolderInstanceAsync(
  connection: BridgeConnection,
  cwd: string
): Promise<FolderInstance | undefined> {
  const instances = connection.listInstances();
  if (instances.length < 2) {
    return undefined;
  }

  const configPath = await findDeployConfigPathAsync(cwd);
  if (!configPath) {
    return undefined;
  }
  let places: DeployPlace[];
  try {
    places = listDeployPlaces(
      await loadDeployConfigAsync(configPath),
      configPath
    );
  } catch {
    return undefined;
  }

  const placeIds = await readInstancePlaceIdsAsync(connection);
  const matches = placeIds.flatMap(({ instanceId, placeId }) => {
    const deployPlace = places.find((p) => p.place.placeId === placeId);
    return deployPlace ? [{ instanceId, deployPlace }] : [];
  });
  return matches.length === 1 ? matches[0] : undefined;
}

/** The connected Studios whose open place is `placeId`. */
export async function findInstancesShowingPlaceAsync(
  connection: BridgeConnection,
  placeId: number
): Promise<string[]> {
  const placeIds = await readInstancePlaceIdsAsync(connection);
  return placeIds
    .filter((instance) => instance.placeId === placeId)
    .map((instance) => instance.instanceId);
}

async function readInstancePlaceIdsAsync(
  connection: BridgeConnection
): Promise<Array<{ instanceId: string; placeId: number | undefined }>> {
  return Promise.all(
    connection.listInstances().map(async (instance) => ({
      instanceId: instance.instanceId,
      placeId: await tryGetPlaceIdAsync(connection, instance),
    }))
  );
}

/** A cloud place loads after the plugin registers, so a registered 0 is read again live. */
async function tryGetPlaceIdAsync(
  connection: BridgeConnection,
  instance: InstanceInfo
): Promise<number | undefined> {
  if (instance.placeId) {
    return instance.placeId;
  }

  const editSession = connection
    .listSessions()
    .find((s) => s.instanceId === instance.instanceId && s.context === 'edit');
  const session = editSession && connection.getSession(editSession.sessionId);
  if (!session) {
    return undefined;
  }

  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const state = await Promise.race([
      session.queryStateAsync(),
      new Promise<undefined>((resolve) => {
        timer = setTimeout(() => resolve(undefined), PLACE_ID_QUERY_TIMEOUT_MS);
      }),
    ]);
    return state?.placeId;
  } catch {
    return undefined;
  } finally {
    clearTimeout(timer);
  }
}
