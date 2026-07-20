import * as fs from 'fs/promises';
import * as path from 'path';

export interface BasePlaceConfig {
  universeId: number;
  placeId: number;
  /**
   * Pin the base place to a specific published version. When set, the deploy
   * downloads exactly this version instead of whatever is currently live, so
   * builds are reproducible and a broken Studio edit can't leak into a deploy.
   * Omit to always pull the latest version. Bump it with
   * `nevermore deploy version upgrade`.
   */
  version?: number;
}

export interface DeployTarget {
  /** Set on places that belong to a multi-place target (e.g. "chapter0"). */
  name?: string;
  universeId: number;
  placeId: number;
  project: string;
  scriptTemplate?: string;
  basePlace?: BasePlaceConfig;
}

/** Wire-format shape: a target may be a single place or a `{ places: [...] }` group. */
export interface MultiPlaceTargetConfig {
  places: DeployTarget[];
}

export type DeployTargetConfig = DeployTarget | MultiPlaceTargetConfig;

export interface DeployConfig {
  universeId?: number;
  targets: Record<string, DeployTargetConfig>;
}

/**
 * The subset of a resolved place that gets baked into the runtime manifest
 * (see the nevermore-cli-manifest package). A deployed place carries the whole
 * target's place table so it can resolve its siblings' IDs at runtime — e.g. a
 * chapter place teleporting to another chapter without hard-coding place IDs.
 */
export interface ManifestPlaceInfo {
  /** Place name from a multi-place target (e.g. "chapter0"); absent for single-place targets. */
  name?: string;
  placeId: number;
  universeId: number;
}

/** Project a resolved deploy place down to the fields stamped into the manifest. */
export function toManifestPlaceInfo(place: DeployTarget): ManifestPlaceInfo {
  return {
    name: place.name,
    placeId: place.placeId,
    universeId: place.universeId,
  };
}

function _isMultiPlace(
  target: DeployTargetConfig
): target is MultiPlaceTargetConfig {
  return Array.isArray((target as MultiPlaceTargetConfig).places);
}

function _validatePlace(label: string, place: DeployTarget): void {
  if (typeof place.universeId !== 'number') {
    throw new Error(`${label} is missing or has invalid "universeId"`);
  }
  if (typeof place.placeId !== 'number') {
    throw new Error(`${label} is missing or has invalid "placeId"`);
  }
  if (typeof place.project !== 'string') {
    throw new Error(`${label} is missing or has invalid "project"`);
  }
  if (place.basePlace != null) {
    if (typeof place.basePlace.universeId !== 'number') {
      throw new Error(
        `${label} basePlace is missing or has invalid "universeId"`
      );
    }
    if (typeof place.basePlace.placeId !== 'number') {
      throw new Error(`${label} basePlace is missing or has invalid "placeId"`);
    }
    if (
      place.basePlace.version != null &&
      (!Number.isInteger(place.basePlace.version) ||
        place.basePlace.version < 1)
    ) {
      throw new Error(
        `${label} basePlace "version" must be a positive integer when set`
      );
    }
  }
}

export async function loadDeployConfigAsync(
  configPath: string
): Promise<DeployConfig> {
  let content: string;
  try {
    content = await fs.readFile(configPath, 'utf-8');
  } catch {
    throw new Error(
      `deploy.nevermore.json not found at ${configPath}\nRun "nevermore deploy init" to create one.`
    );
  }

  const config = JSON.parse(content) as DeployConfig;

  if (!config.targets || typeof config.targets !== 'object') {
    throw new Error(
      `deploy.nevermore.json at ${configPath} is missing "targets" field`
    );
  }

  for (const [name, target] of Object.entries(config.targets)) {
    if (_isMultiPlace(target)) {
      if (target.places.length === 0) {
        throw new Error(`Target "${name}" has an empty "places" array`);
      }
      for (const [i, place] of target.places.entries()) {
        const placeLabel = place.name
          ? `Target "${name}" place "${place.name}"`
          : `Target "${name}" places[${i}]`;
        _validatePlace(placeLabel, place);
      }
    } else {
      _validatePlace(`Target "${name}"`, target);
    }
  }

  return config;
}

/**
 * Expand a target into one DeployTarget per place. Single-place targets resolve
 * to a 1-element array; multi-place targets expand to one entry per `places[]`.
 */
export function resolveDeployTargetPlaces(
  config: DeployConfig,
  targetName: string
): DeployTarget[] {
  const availableTargets = Object.keys(config.targets);
  const target = config.targets[targetName];

  if (!target) {
    throw new Error(
      [
        `Target "${targetName}" not found in deploy.nevermore.json.`,
        `Available targets: ${availableTargets.join(', ')}`,
      ].join('\n')
    );
  }

  return _isMultiPlace(target) ? target.places : [target];
}

/**
 * Like `resolveDeployTarget`, but throws when the target is multi-place. Use
 * in single-shot commands (`nevermore deploy`, `nevermore test`) where it is
 * not meaningful to deploy to "the first place" of a multi-chapter target —
 * the caller should pick one explicitly or use the batch commands.
 */
export function resolveSingleDeployTarget(
  config: DeployConfig,
  targetName: string,
  commandHint = 'nevermore batch deploy'
): DeployTarget {
  const places = resolveDeployTargetPlaces(config, targetName);
  if (places.length > 1) {
    const placeNames = places
      .map((p, i) => p.name ?? `places[${i}]`)
      .join(', ');
    throw new Error(
      [
        `Target "${targetName}" has multiple places (${placeNames}); cannot deploy to it as a single place.`,
        `Use \`${commandHint} --target ${targetName}\` to fan out across every place.`,
      ].join('\n')
    );
  }
  return places[0]!;
}

/**
 * Pick a target name when the user did not specify one and we cannot prompt
 * (non-TTY / CI). Single target wins; otherwise prefer "integration" over
 * "test" so `--publish` does not silently target the test place. Throws when
 * neither is present.
 */
export function resolveDefaultTargetName(config: DeployConfig): string {
  const availableTargets = Object.keys(config.targets);

  if (availableTargets.length === 1) {
    return availableTargets[0]!;
  }
  if (config.targets['integration']) {
    return 'integration';
  }
  if (config.targets['test']) {
    return 'test';
  }

  throw new Error(
    [
      'No --target specified and no default could be inferred.',
      `Available targets: ${availableTargets.join(', ')}`,
    ].join('\n')
  );
}

export function resolveDeployConfigPath(packagePath: string): string {
  return path.resolve(packagePath, 'deploy.nevermore.json');
}

/**
 * Walk up from startPath looking for a deploy.nevermore.json with a universeId.
 * Returns the first universeId found, or undefined.
 */
export async function discoverUniverseIdAsync(
  startPath: string
): Promise<number | undefined> {
  let current = path.resolve(startPath);

  while (true) {
    const configPath = path.join(current, 'deploy.nevermore.json');
    try {
      const content = await fs.readFile(configPath, 'utf-8');
      const config = JSON.parse(content) as Partial<DeployConfig>;

      if (typeof config.universeId === 'number') {
        return config.universeId;
      }

      // Check if any target (or any place within a multi-place target) has a universeId
      if (config.targets) {
        for (const target of Object.values(config.targets)) {
          const places = _isMultiPlace(target) ? target.places : [target];
          for (const place of places) {
            if (typeof place.universeId === 'number') {
              return place.universeId;
            }
          }
        }
      }
    } catch {
      // No deploy.nevermore.json here, keep walking up
    }

    const parent = path.dirname(current);
    if (parent === current) {
      break;
    }
    current = parent;
  }

  return undefined;
}
