import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { rojoBuildAsync } from '@quenty/nevermore-template-helpers';
import {
  DeployTarget,
  loadDeployConfigAsync,
  resolveDeployTarget,
  resolveDeployConfigPath,
} from './deploy-config.js';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';

export interface DeployOverrides {
  universeId?: number;
  placeId?: number;
  scriptTemplate?: string;
  placeFile?: string;
}

export interface BuildPlaceOptions {
  targetName: string;
  outputFileName?: string;
  packagePath?: string;
  overrides?: DeployOverrides;
  reporter?: Reporter;
  packageName?: string;
}

export interface BuildPlaceResult {
  rbxlPath: string;
  target: DeployTarget;
}

/**
 * Build a .rbxl place file via rojo from a deploy.nevermore.json target.
 * Shared by both local test execution and cloud (build + upload) paths.
 */
export async function buildPlaceAsync(
  options: BuildPlaceOptions
): Promise<BuildPlaceResult> {
  const {
    targetName,
    outputFileName = 'build.rbxl',
    packagePath = process.cwd(),
    overrides,
    reporter,
    packageName,
  } = options;

  const configPath = resolveDeployConfigPath(packagePath);
  const config = await loadDeployConfigAsync(configPath);
  const target = { ...resolveDeployTarget(config, targetName) };

  if (overrides?.universeId) target.universeId = overrides.universeId;
  if (overrides?.placeId) target.placeId = overrides.placeId;
  if (overrides?.scriptTemplate)
    target.scriptTemplate = overrides.scriptTemplate;

  if (overrides?.placeFile) {
    const rbxlPath = path.resolve(overrides.placeFile);
    OutputHelper.verbose(`Using pre-built place file: ${rbxlPath}`);

    try {
      await fs.access(rbxlPath);
    } catch {
      throw new Error(`Place file not found: ${rbxlPath}`);
    }

    return { rbxlPath, target };
  }

  const projectPath = path.resolve(packagePath, target.project);
  const rbxlPath = path.resolve(packagePath, 'build', outputFileName);

  const resolvedPackageName = packageName ?? path.basename(packagePath);
  reporter?.onPackagePhaseChange(resolvedPackageName, 'building');
  OutputHelper.verbose(
    `Building rojo project ${resolvedPackageName}/${target.project}...`
  );

  await fs.mkdir(path.dirname(rbxlPath), { recursive: true });
  await rojoBuildAsync({ projectPath, output: rbxlPath });

  return { rbxlPath, target };
}
