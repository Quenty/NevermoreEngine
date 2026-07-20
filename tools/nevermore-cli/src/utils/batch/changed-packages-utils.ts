import * as fs from 'fs/promises';
import { execa } from 'execa';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  DeployTarget,
  ManifestPlaceInfo,
  loadDeployConfigAsync,
  resolveDeployConfigPath,
  resolveDeployTargetPlaces,
  toManifestPlaceInfo,
} from '../build/deploy-config.js';

export interface TargetPackage {
  name: string;
  path: string;
  /**
   * Every place this package deploys to under the chosen target. For a
   * single-place target this has length 1; for a multi-place target (e.g.
   * `places: [chapter0, chapter1]`) it has one entry per place.
   */
  activeTargets: DeployTarget[];
}

/**
 * One runnable unit: a single place to build / deploy / test. Multi-place
 * targets fan out into one BatchTarget per place; the place's `name` is
 * appended to the display name (e.g. `@x/y - chapter0`).
 */
export interface BatchTarget {
  /** Display name. Suffixed with ` - <place.name>` for fanned-out places. */
  name: string;
  /** Underlying package name (no suffix), used to load files relative to the package. */
  packageName: string;
  /** Package directory. */
  path: string;
  /** The single resolved place this BatchTarget represents. */
  target: DeployTarget;
  /**
   * Every place of this package's target (including `target` itself), stamped
   * into the runtime manifest so a deployed place can resolve its siblings' IDs.
   * Same for every BatchTarget fanned out from one package. Only the deploy
   * paths populate this; test/script BatchTargets omit it.
   */
  manifestPlaces?: ManifestPlaceInfo[];
}

/**
 * Discover all packages that have a deploy.nevermore.json with the given target.
 */
export async function discoverAllTargetPackagesAsync(
  targetName: string
): Promise<TargetPackage[]> {
  const { stdout } = await execa('pnpm', [
    'ls',
    '--json',
    '-r',
    '--depth',
    '-1',
  ]);

  const packages = JSON.parse(stdout) as Array<{ name: string; path: string }>;
  return _filterByTargetAsync(packages, targetName);
}

/**
 * Discover packages with the given target that have changed since `baseBranch`.
 * Uses pnpm's --filter "...[<base>]" to include transitive dependents.
 */
export async function discoverChangedTargetPackagesAsync(
  baseBranch: string,
  targetName: string
): Promise<TargetPackage[]> {
  // pnpm --filter "...[origin/main]" lists changed packages + their dependents
  const { stdout } = await execa('pnpm', [
    'ls',
    '--json',
    '-r',
    '--depth',
    '-1',
    '--filter',
    `...[${baseBranch}]`,
  ]);

  let packages: Array<{ name: string; path: string }>;
  try {
    packages = JSON.parse(stdout);
  } catch {
    return [];
  }

  if (!Array.isArray(packages) || packages.length === 0) {
    return [];
  }

  return _filterByTargetAsync(packages, targetName);
}

/**
 * Discover all packages that have a deploy.nevermore.json with a "test" target
 * and a scriptTemplate (required for running tests).
 */
export async function discoverAllTestableBatchTargetsAsync(): Promise<
  BatchTarget[]
> {
  const packages = await discoverAllTargetPackagesAsync('test');
  return _requireScriptTemplate(flattenToBatchTargets(packages));
}

/**
 * Discover packages with test targets that have changed since `baseBranch`.
 * Only includes targets with a scriptTemplate (required for running tests).
 * Uses pnpm's --filter "...[<base>]" to include transitive dependents.
 */
export async function discoverChangedTestableBatchTargetsAsync(
  baseBranch: string
): Promise<BatchTarget[]> {
  const packages = await discoverChangedTargetPackagesAsync(baseBranch, 'test');
  return _requireScriptTemplate(flattenToBatchTargets(packages));
}

/**
 * Fan a list of TargetPackages out into BatchTargets — one per place. A
 * single-place package produces one BatchTarget with the package name; a
 * multi-place package produces one per place, with ` - <place.name>` suffix.
 */
export function flattenToBatchTargets(
  packages: TargetPackage[]
): BatchTarget[] {
  const result: BatchTarget[] = [];
  for (const pkg of packages) {
    const manifestPlaces = pkg.activeTargets.map(toManifestPlaceInfo);
    if (pkg.activeTargets.length === 1) {
      result.push({
        name: pkg.name,
        packageName: pkg.name,
        path: pkg.path,
        target: pkg.activeTargets[0]!,
        manifestPlaces,
      });
      continue;
    }
    for (const target of pkg.activeTargets) {
      const suffix = target.name;
      const name = suffix ? `${pkg.name} - ${suffix}` : pkg.name;
      result.push({
        name,
        packageName: pkg.name,
        path: pkg.path,
        target,
        manifestPlaces,
      });
    }
  }
  return result;
}

/**
 * Filter out targets without a scriptTemplate — those are deploy-only places
 * (e.g. integration games) that can't be tested via `batch test`.
 */
function _requireScriptTemplate(targets: BatchTarget[]): BatchTarget[] {
  const withTemplate: BatchTarget[] = [];
  const skipped: string[] = [];

  for (const buildTarget of targets) {
    if (buildTarget.target.scriptTemplate) {
      withTemplate.push(buildTarget);
    } else {
      skipped.push(buildTarget.name);
    }
  }

  if (skipped.length > 0) {
    OutputHelper.verbose(
      `Skipped ${skipped.length} targets without scriptTemplate: ${skipped.join(
        ', '
      )}`
    );
  }

  return withTemplate;
}

async function _filterByTargetAsync(
  packages: Array<{ name: string; path: string }>,
  targetName: string
): Promise<TargetPackage[]> {
  const results: TargetPackage[] = [];
  const skippedNoConfig: string[] = [];
  const skippedNoTarget: string[] = [];

  for (const pkg of packages) {
    const configPath = resolveDeployConfigPath(pkg.path);

    try {
      await fs.access(configPath);
    } catch {
      skippedNoConfig.push(pkg.name);
      continue;
    }

    try {
      const config = await loadDeployConfigAsync(configPath);
      const activeTargets = resolveDeployTargetPlaces(config, targetName);
      results.push({ name: pkg.name, path: pkg.path, activeTargets });
    } catch {
      skippedNoTarget.push(pkg.name);
    }
  }

  if (skippedNoConfig.length > 0) {
    OutputHelper.verbose(
      `Skipped ${skippedNoConfig.length} packages without deploy.nevermore.json`
    );
  }

  if (skippedNoTarget.length > 0) {
    OutputHelper.verbose(
      `Skipped ${
        skippedNoTarget.length
      } packages without a "${targetName}" target: ${skippedNoTarget.join(
        ', '
      )}`
    );
  }

  return results;
}
