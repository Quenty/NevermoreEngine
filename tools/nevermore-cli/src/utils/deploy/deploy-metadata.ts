import { execSync } from 'child_process';
import * as fs from 'fs/promises';
import * as path from 'path';
import {
  BuildContext,
  resolvePackagePath,
} from '@quenty/nevermore-template-helpers';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { type BuiltPlace } from '../build/build.js';
import { type ManifestPlaceInfo } from '../build/deploy-config.js';

/** npm name of the package that ships the manifest module. */
export const MANIFEST_PACKAGE_NAME = '@quenty/nevermoreclimanifest';

/**
 * Attribute map written onto the built place's NevermoreCLIManifestUtils module.
 * Keys are attribute names and MUST match the `ATTRIBUTE` table in
 * src/nevermore-cli-manifest/src/Shared/NevermoreCLIManifestUtils.lua.
 */
export type DeployMetadataAttributes = Record<
  string,
  string | number | boolean
>;

const INJECT_SCRIPT_PATH = resolvePackagePath(
  import.meta.url,
  'build-scripts',
  'transform-inject-deploy-metadata.luau'
);

function _git(args: string[]): string | undefined {
  try {
    return execSync(`git ${args.join(' ')}`, {
      encoding: 'utf-8',
      timeout: 5000,
      stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();
  } catch {
    return undefined;
  }
}

/** Git facts about the working tree the deploy was built from. */
export interface GitDeployInfo {
  /** Short commit SHA, e.g. "a1b2c3d". */
  commit?: string;
  /** Full commit SHA. */
  version?: string;
  /** Current branch name, or undefined in a detached HEAD. */
  branch?: string;
}

/**
 * Collect git metadata once per deploy. Every field is best-effort — a missing
 * git binary or a non-repo directory yields an empty object rather than an error.
 */
export function gatherGitDeployInfo(): GitDeployInfo {
  const info: GitDeployInfo = {};
  const commit = _git(['rev-parse', '--short', 'HEAD']);
  if (commit) info.commit = commit;
  const version = _git(['rev-parse', 'HEAD']);
  if (version) info.version = version;
  const branch = _git(['rev-parse', '--abbrev-ref', 'HEAD']);
  if (branch && branch !== 'HEAD') info.branch = branch;
  return info;
}

/** Per-place facts known at deploy time. */
export interface DeployPlaceInfo {
  /** Deploy target name from deploy.nevermore.json (e.g. "test", "integration"). */
  target: string;
  /** True when published live (`--publish`); false when only Saved. */
  published: boolean;
  /** ISO 8601 timestamp — pass one value for the whole deploy so every place agrees. */
  timestamp: string;
  placeId: number;
  universeId: number;
}

/**
 * Build the attribute map injected into the built place. `Deployed` is always
 * true here — its mere presence is what distinguishes a deployed build from a
 * Studio session at runtime.
 *
 * Place and universe IDs are stringified on purpose: Roblox `number` attributes
 * round-trip through Lune serialization as float32, which silently corrupts IDs
 * above 2^24 (e.g. 123456789 -> 123456792). Strings are exact; the Luau reader
 * converts them back with `tonumber`.
 *
 * When `places` is given (the whole target's place table), it is stamped as a
 * `Places` JSON-string attribute. The IDs inside stay numeric — a JSON string
 * is exact text, and the Luau reader decodes it to 64-bit numbers, so the
 * float32 hazard that forces the top-level IDs to be stringified doesn't apply.
 */
export function buildDeployMetadataAttributes(
  git: GitDeployInfo,
  place: DeployPlaceInfo,
  places?: readonly ManifestPlaceInfo[]
): DeployMetadataAttributes {
  const attributes: DeployMetadataAttributes = {
    Deployed: true,
    Target: place.target,
    Timestamp: place.timestamp,
    Published: place.published,
    PlaceId: String(place.placeId),
    UniverseId: String(place.universeId),
  };
  if (git.commit) attributes.Commit = git.commit;
  if (git.version) attributes.Version = git.version;
  if (git.branch) attributes.Branch = git.branch;
  if (places && places.length > 0) {
    attributes.Places = JSON.stringify(
      places.map((p) => ({
        name: p.name,
        placeId: p.placeId,
        universeId: p.universeId,
      }))
    );
  }
  return attributes;
}

/** A built place with metadata injected, plus a handle to clean up its temp dir. */
export interface InjectedPlace {
  builtPlace: BuiltPlace;
  cleanupAsync(): Promise<void>;
}

/**
 * Run the Lune transform that writes `attributes` onto the place's manifest
 * module. Produces a fresh .rbxl in its own temp directory so a shared rojo
 * build (multi-place / batch deploys) is never mutated in place. The caller
 * uploads `result.builtPlace` and then calls `result.cleanupAsync()`.
 */
export async function injectDeployMetadataAsync(
  builtPlace: BuiltPlace,
  attributes: DeployMetadataAttributes
): Promise<InjectedPlace> {
  const context = await BuildContext.createAsync({ prefix: 'deploy-meta-' });
  const outputPath = context.resolvePath('deploy-metadata.rbxl');

  OutputHelper.verbose('Injecting deploy metadata into built place...');
  await context.executeLuneTransformScriptAsync(
    INJECT_SCRIPT_PATH,
    builtPlace.rbxlPath,
    outputPath,
    JSON.stringify(attributes)
  );

  return {
    builtPlace: { ...builtPlace, rbxlPath: outputPath },
    cleanupAsync: () => context.cleanupAsync(),
  };
}

/**
 * Inject `attributes` by rewriting `rbxlPath` in place. Only safe when the
 * caller owns the file exclusively (e.g. a per-session test build); deploys use
 * {@link injectDeployMetadataAsync} instead because they can share one rojo
 * build across multiple places.
 */
export async function injectDeployMetadataInPlaceAsync(
  rbxlPath: string,
  attributes: DeployMetadataAttributes
): Promise<void> {
  const context = await BuildContext.createAsync({ prefix: 'deploy-meta-' });
  try {
    OutputHelper.verbose('Injecting deploy metadata into test build...');
    // The transform reads the whole input before writing, so input === output
    // rewrites the file safely.
    await context.executeLuneTransformScriptAsync(
      INJECT_SCRIPT_PATH,
      rbxlPath,
      rbxlPath,
      JSON.stringify(attributes)
    );
  } finally {
    await context.cleanupAsync();
  }
}

/**
 * True when the package at `packagePath` ships or directly depends on the
 * manifest package, so its built place will contain the module to inject into.
 * Gates injection during tests so unrelated packages don't pay for a Lune pass.
 */
export async function packageUsesManifestAsync(
  packagePath: string
): Promise<boolean> {
  try {
    const raw = await fs.readFile(
      path.join(packagePath, 'package.json'),
      'utf-8'
    );
    const pkg = JSON.parse(raw) as {
      name?: string;
      dependencies?: Record<string, string>;
      devDependencies?: Record<string, string>;
    };
    if (pkg.name === MANIFEST_PACKAGE_NAME) {
      return true;
    }
    return Boolean(
      pkg.dependencies?.[MANIFEST_PACKAGE_NAME] ??
        pkg.devDependencies?.[MANIFEST_PACKAGE_NAME]
    );
  } catch {
    return false;
  }
}
