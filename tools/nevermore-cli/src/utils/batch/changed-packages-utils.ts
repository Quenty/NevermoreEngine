import * as fs from 'fs/promises';
import { execa } from 'execa';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  DeployTarget,
  loadDeployConfigAsync,
  resolveDeployConfigPath,
  resolveDeployTarget,
} from '../build/deploy-config.js';

export interface TargetPackage {
  name: string;
  path: string;
  target: DeployTarget;
}

/** @deprecated Use {@link TargetPackage} instead. */
export type TestablePackage = TargetPackage;

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
export async function discoverAllTestablePackagesAsync(): Promise<
  TargetPackage[]
> {
  const packages = await discoverAllTargetPackagesAsync('test');
  return _requireScriptTemplate(packages);
}

/**
 * Discover packages with test targets that have changed since `baseBranch`.
 * Only includes packages with a scriptTemplate (required for running tests).
 * Uses pnpm's --filter "...[<base>]" to include transitive dependents.
 */
export async function discoverChangedTestablePackagesAsync(
  baseBranch: string
): Promise<TargetPackage[]> {
  const packages = await discoverChangedTargetPackagesAsync(baseBranch, 'test');
  return _requireScriptTemplate(packages);
}

/**
 * Filter out packages without a scriptTemplate — those are deploy-only targets
 * (e.g. integration games) that can't be tested via `batch test`.
 */
function _requireScriptTemplate(packages: TargetPackage[]): TargetPackage[] {
  const withTemplate: TargetPackage[] = [];
  const skipped: string[] = [];

  for (const pkg of packages) {
    if (pkg.target.scriptTemplate) {
      withTemplate.push(pkg);
    } else {
      skipped.push(pkg.name);
    }
  }

  if (skipped.length > 0) {
    OutputHelper.verbose(
      `Skipped ${skipped.length} packages without scriptTemplate: ${skipped.join(', ')}`
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
      const target = resolveDeployTarget(config, targetName);
      results.push({ name: pkg.name, path: pkg.path, target });
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
