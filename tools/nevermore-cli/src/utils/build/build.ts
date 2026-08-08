import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { BuildContext } from '@quenty/nevermore-template-helpers';
import { DeployTarget } from '@quenty/nevermore-deploy';
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
  /**
   * Directory the package lives in. Required, not defaulted.
   *
   * Everything downstream is resolved against it: the project file, the build
   * cache key, and which `deploy.nevermore.lock.json` a base place pin is
   * written to. Falling back to `process.cwd()` is silently wrong in a batch —
   * every package sharing a relative `project` path collapses onto one cache
   * key, so one package's build gets uploaded to another's place. It was
   * optional once, and a refactor dropped it from a call site with nothing to
   * catch it.
   */
  packagePath: string;
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
  /**
   * Concrete version of the base place this build merged against, once one has
   * been merged.
   *
   * Resolved during the merge and carried out because nothing downstream can
   * recover it: a `"published"` pin resolves at deploy time, and by the time
   * the place is running, the base place has usually moved on. Without it, a
   * build in game cannot say which upstream content it is actually made of.
   */
  basePlaceVersion?: number;
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
