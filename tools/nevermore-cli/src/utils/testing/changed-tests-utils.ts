import * as fs from 'fs/promises';
import { execa } from 'execa';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  DeployTarget,
  loadDeployConfigAsync,
  resolveDeployConfigPath,
  resolveDeployTarget,
} from '../build/deploy-config.js';

export interface TestablePackage {
  name: string;
  path: string;
  target: DeployTarget;
}

/**
 * Discover all packages that have a deploy.nevermore.json with a "test" target.
 */
export async function discoverAllTestablePackagesAsync(): Promise<
  TestablePackage[]
> {
  const { stdout } = await execa('pnpm', [
    'ls',
    '--json',
    '-r',
    '--depth',
    '-1',
  ]);

  const packages = JSON.parse(stdout) as Array<{ name: string; path: string }>;
  return _filterTestableAsync(packages);
}

/**
 * Discover packages with test targets that have changed since `baseBranch`.
 * Uses pnpm's --filter "...[<base>]" to include transitive dependents.
 */
export async function discoverChangedTestablePackagesAsync(
  baseBranch: string
): Promise<TestablePackage[]> {
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

  return _filterTestableAsync(packages);
}

async function _filterTestableAsync(
  packages: Array<{ name: string; path: string }>
): Promise<TestablePackage[]> {
  const results: TestablePackage[] = [];
  const skippedNoConfig: string[] = [];
  const skippedNoTestTarget: string[] = [];

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
      const target = resolveDeployTarget(config, 'test');
      results.push({ name: pkg.name, path: pkg.path, target });
    } catch {
      skippedNoTestTarget.push(pkg.name);
    }
  }

  if (skippedNoConfig.length > 0) {
    OutputHelper.verbose(
      `Skipped ${skippedNoConfig.length} packages without deploy.nevermore.json`
    );
  }

  if (skippedNoTestTarget.length > 0) {
    OutputHelper.verbose(
      `Skipped ${
        skippedNoTestTarget.length
      } packages without a "test" target: ${skippedNoTestTarget.join(', ')}`
    );
  }

  return results;
}
