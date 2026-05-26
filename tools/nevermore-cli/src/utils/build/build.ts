import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { BuildContext } from '@quenty/nevermore-template-helpers';
import { DeployTarget } from './deploy-config.js';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';

export interface DeployOverrides {
  universeId?: number;
  placeId?: number;
  scriptTemplate?: string;
  placeFile?: string;
}

export interface BuildPlaceOptions {
  /**
   * Resolved place to build. The caller picks which place — multi-place targets
   * must be fanned out (see flattenToBatchTargets) before reaching this point,
   * otherwise places[1..] would be silently dropped.
   */
  target: DeployTarget;
  outputFileName?: string;
  packagePath?: string;
  overrides?: DeployOverrides;
  reporter?: Reporter;
  packageName?: string;
}

/**
 * Opaque handle representing a built place file.
 * Callers see only the path and target — lifecycle is managed by the JobContext.
 */
export interface BuiltPlace {
  rbxlPath: string;
  target: DeployTarget;
}

export interface BuildPlaceResult extends BuiltPlace {
  /** Present when a rojo build was performed; undefined when using a pre-built placeFile. */
  buildContext?: BuildContext;
}

/**
 * Build a .rbxl place file via rojo from a resolved deploy target.
 * Shared by both local test execution and cloud (build + upload) paths.
 */
export async function buildPlaceAsync(
  options: BuildPlaceOptions
): Promise<BuildPlaceResult> {
  const {
    target: inputTarget,
    outputFileName = 'build.rbxl',
    packagePath = process.cwd(),
    overrides,
    reporter,
    packageName,
  } = options;

  const target: DeployTarget = { ...inputTarget };

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

  const resolvedPackageName = packageName ?? path.basename(packagePath);
  reporter?.onPackagePhaseChange(resolvedPackageName, 'building');
  OutputHelper.verbose(
    `Building rojo project ${resolvedPackageName}/${target.project}...`
  );

  const buildContext = await BuildContext.createAsync({
    prefix: 'rojo-build-',
  });
  const rbxlPath = buildContext.resolvePath(outputFileName);
  await buildContext.rojoBuildAsync({ projectPath, output: rbxlPath });

  return { rbxlPath, target, buildContext };
}
