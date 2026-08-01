import * as fs from 'fs/promises';
import * as path from 'path';
import {
  formatTargetSelector,
  parseTargetSelector,
} from './target-selector.js';

/**
 * The two symbolic `basePlace.version` pins. Unlike a number, these resolve at
 * deploy time against the base place's version history:
 *
 * - `"published"` — the newest version that has been published live.
 * - `"saved"` — the newest version of any kind, including Studio saves that
 *   were never published.
 *
 * "Resolved at deploy time" means the first deploy after the pin changes; the
 * answer is then held in `deploy.nevermore.lock.json` so builds stay
 * reproducible.
 *
 * They match the `versionType` vocabulary the Open Cloud place-publishing API
 * uses when uploading, so a config reads the same way in both directions.
 */
export const BASE_PLACE_VERSION_KEYWORDS = ['saved', 'published'] as const;

export type BasePlaceVersionKeyword =
  typeof BASE_PLACE_VERSION_KEYWORDS[number];

/** An exact version number, or a keyword resolved at deploy time. */
export type BasePlaceVersion = number | BasePlaceVersionKeyword;

export function isBasePlaceVersionKeyword(
  version: BasePlaceVersion
): version is BasePlaceVersionKeyword {
  return typeof version === 'string';
}

export interface BasePlaceConfig {
  universeId: number;
  placeId: number;
  /**
   * Pin the base place to a specific version. A number downloads exactly that
   * version, so builds are reproducible and a broken Studio edit can't leak
   * into a deploy — bump it with `nevermore deploy version upgrade`.
   *
   * `"published"` and `"saved"` instead name which end of the base place's
   * history to follow. They are resolved once and recorded in
   * `deploy.nevermore.lock.json`, then reused until `deploy version upgrade`
   * moves them — the keyword is the intent, the lock holds the fact. Use these
   * when the base place is meant to move with Studio rather than be held still.
   *
   * Omitting it behaves as `"published"`, so a config that never opted into
   * pinning still deploys reproducibly.
   */
  version?: BasePlaceVersion;
}

export interface DeployTarget {
  /** Set on places that belong to a multi-place target (e.g. "chapter0"). */
  name?: string;
  universeId: number;
  placeId: number;
  project: string;
  scriptTemplate?: string;
  basePlace?: BasePlaceConfig;
  /**
   * Repo-relative path to the GitHub workflow that rebuilds this place, e.g.
   * `.github/workflows/build.yml`. Declaring it makes the place eligible for
   * `--watch`: a watch registration asks for that workflow to be dispatched
   * with this place's selector (`integration.places.hub`) whenever the place's
   * `basePlace` gains a new version, so a Studio edit upstream rebuilds and
   * redeploys without anyone pushing a commit.
   *
   * It is only ever a dispatch address. Nothing here reads the workflow file,
   * and a place without a `basePlace` has nothing to watch — `--watch` skips it
   * rather than registering a watch that can never fire.
   */
  watch?: string;
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

function _validateBasePlaceVersion(label: string, version: unknown): void {
  if (version == null) {
    return;
  }
  if (typeof version === 'string') {
    if (!(BASE_PLACE_VERSION_KEYWORDS as readonly string[]).includes(version)) {
      throw new Error(
        `${label} basePlace "version" must be a positive integer, ` +
          `${BASE_PLACE_VERSION_KEYWORDS.map((k) => `"${k}"`).join(' or ')}` +
          ` — got "${version}"`
      );
    }
    return;
  }
  if (!Number.isInteger(version) || (version as number) < 1) {
    throw new Error(
      `${label} basePlace "version" must be a positive integer, ` +
        `${BASE_PLACE_VERSION_KEYWORDS.map((k) => `"${k}"`).join(' or ')}`
    );
  }
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
  if (place.watch != null) {
    if (typeof place.watch !== 'string' || place.watch === '') {
      throw new Error(
        `${label} "watch" must be a path to a GitHub workflow, ` +
          'e.g. ".github/workflows/build.yml"'
      );
    }
    if (path.isAbsolute(place.watch)) {
      // The path is sent to a dispatcher that resolves it inside the repo, so a
      // machine-local absolute path would name a file that side cannot see.
      throw new Error(
        `${label} "watch" must be repo-relative, got "${place.watch}"`
      );
    }
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
    _validateBasePlaceVersion(label, place.basePlace.version);
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
 *
 * `selector` is a target name, or a name narrowed to one place inside it
 * (`integration.places.hub`), in which case exactly that place is returned.
 * Narrowing matches on `name` whether or not the target is multi-place, so a
 * selector keeps working when a target grows from one place to several.
 */
export function resolveDeployTargetPlaces(
  config: DeployConfig,
  selector: string
): DeployTarget[] {
  const availableTargets = Object.keys(config.targets);
  const { targetName, placeName } = parseTargetSelector(selector);
  const target = config.targets[targetName];

  if (!target) {
    throw new Error(
      [
        `Target "${targetName}" not found in deploy.nevermore.json.`,
        `Available targets: ${availableTargets.join(', ')}`,
      ].join('\n')
    );
  }

  const places = _isMultiPlace(target) ? target.places : [target];
  if (placeName == null) {
    return places;
  }

  const place = places.find((p) => p.name === placeName);
  if (!place) {
    const named = places.flatMap((p) => (p.name == null ? [] : [p.name]));
    throw new Error(
      [
        `Target "${targetName}" has no place named "${placeName}".`,
        named.length > 0
          ? `Available places: ${named.join(', ')}`
          : `That target's places have no "name" field to select by.`,
      ].join('\n')
    );
  }
  return [place];
}

/**
 * Like `resolveDeployTarget`, but throws when the selector resolves to more
 * than one place. Use in single-shot commands (`nevermore deploy`,
 * `nevermore test`) where it is not meaningful to deploy to "the first place"
 * of a multi-chapter target — the caller should narrow to one place or use the
 * batch commands.
 */
export function resolveSingleDeployTarget(
  config: DeployConfig,
  selector: string,
  commandHint = 'nevermore batch deploy'
): DeployTarget {
  const places = resolveDeployTargetPlaces(config, selector);
  if (places.length > 1) {
    const { targetName } = parseTargetSelector(selector);
    const placeNames = places
      .map((p, i) => p.name ?? `places[${i}]`)
      .join(', ');
    const named = places.flatMap((p) => (p.name == null ? [] : [p.name]));
    const remedies = [
      `Use \`${commandHint} --target ${targetName}\` to fan out across every place.`,
    ];
    if (named[0] != null) {
      remedies.unshift(
        `Narrow to one place, e.g. \`${formatTargetSelector({
          targetName,
          placeName: named[0],
        })}\`.`
      );
    }
    throw new Error(
      [
        `Target "${targetName}" has multiple places (${placeNames}); cannot deploy to it as a single place.`,
        ...remedies,
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
