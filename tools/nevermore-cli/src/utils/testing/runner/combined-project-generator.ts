import * as fs from 'fs/promises';
import * as path from 'path';
import {
  BuildContext,
  resolvePackagePath,
} from '@quenty/nevermore-template-helpers';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type DeployTarget,
  loadDeployConfigAsync,
  resolveDeployConfigPath,
  resolveDeployTarget,
} from '../../build/deploy-config.js';
import { type TargetPackage } from '../../batch/changed-packages-utils.js';

export interface CombinedProjectResult {
  /** Absolute path to the combined .rbxl file. */
  rbxlPath: string;
  /** packageName → SSS slug mapping. */
  slugMap: Map<string, string>;
  /** First package's deploy target (provides placeId/universeId for upload). */
  primaryTarget: DeployTarget;
  /** Owns the temp directory — caller must clean up via buildContext.cleanupAsync(). */
  buildContext: BuildContext;
}

interface RojoNode {
  [key: string]: unknown;
}

/** Per-package build info collected during phase 1. */
interface PackageBuildInfo {
  slug: string;
  rbxlPath: string;
  scriptPath: string;
}

/**
 * Build a combined .rbxl containing all testable packages.
 *
 * Two-phase approach to avoid rojo's symlink deduplication:
 *   Phase 1: Build each package's .rbxl individually via rojo
 *   Phase 2: Use Lune to merge the individual builds into a single .rbxl
 */
export async function generateCombinedProjectAsync(options: {
  packages: TargetPackage[];
  repoRoot: string;
  batchPlaceId?: number;
  batchUniverseId?: number;
}): Promise<CombinedProjectResult> {
  const { packages, batchPlaceId, batchUniverseId } = options;

  if (packages.length === 0) {
    throw new Error('No packages provided for combined project generation');
  }

  const buildContext = await BuildContext.createAsync({
    prefix: 'batch-project-',
  });

  const slugMap = new Map<string, string>();
  let primaryTarget: DeployTarget | undefined;
  const builds: PackageBuildInfo[] = [];

  // ── Phase 1: Build each package individually ──

  for (const pkg of packages) {
    const configPath = resolveDeployConfigPath(pkg.path);
    const config = await loadDeployConfigAsync(configPath);
    const target = resolveDeployTarget(config, 'test');

    if (!primaryTarget) {
      primaryTarget = { ...target };
      if (batchPlaceId) primaryTarget.placeId = batchPlaceId;
      if (batchUniverseId) primaryTarget.universeId = batchUniverseId;
    }

    // Parse the rojo project to extract the SSS slug
    const projectPath = path.resolve(pkg.path, target.project);
    const slug = await _extractSlugAsync(pkg.name, projectPath);

    // Validate slug uniqueness
    for (const [existingName, existingSlug] of slugMap) {
      if (existingSlug === slug) {
        throw new Error(
          `Slug collision: ${pkg.name} and ${existingName} both use slug "${slug}"`
        );
      }
    }
    slugMap.set(pkg.name, slug);

    // Build this package's .rbxl
    const rbxlPath = buildContext.resolvePath(`${slug}.rbxl`);
    OutputHelper.verbose(`Building ${pkg.name} (${slug})...`);
    await buildContext.rojoBuildAsync({ projectPath, output: rbxlPath });

    // Resolve scriptTemplate path
    if (!target.scriptTemplate) {
      throw new Error(
        `No scriptTemplate for ${pkg.name} — required for batch testing`
      );
    }
    const scriptPath = path.resolve(pkg.path, target.scriptTemplate);

    builds.push({ slug, rbxlPath, scriptPath });
  }

  // ── Phase 2: Merge via Lune ──

  const combinedRbxlPath = buildContext.resolvePath('batch-test.rbxl');
  const luneScriptPath = resolvePackagePath(
    import.meta.url,
    'build-scripts',
    'combine-test-places.luau'
  );

  // Build args: <outputPath> <slug1> <rbxl1> <script1> <slug2> <rbxl2> <script2> ...
  const luneArgs: string[] = [combinedRbxlPath];
  for (const build of builds) {
    luneArgs.push(build.slug, build.rbxlPath, build.scriptPath);
  }

  OutputHelper.verbose(
    `Merging ${builds.length} packages into combined .rbxl...`
  );
  await buildContext.executeLuneTransformScriptAsync(luneScriptPath, ...luneArgs);

  OutputHelper.verbose(
    `Combined ${slugMap.size} packages at ${combinedRbxlPath}`
  );

  return {
    rbxlPath: combinedRbxlPath,
    slugMap,
    primaryTarget: primaryTarget!,
    buildContext,
  };
}

/**
 * Extract the package slug from a test rojo project.
 * The slug is the first non-`$`, non-`Script` key under ServerScriptService.
 */
async function _extractSlugAsync(
  packageName: string,
  projectPath: string
): Promise<string> {
  let content: string;
  try {
    content = await fs.readFile(projectPath, 'utf-8');
  } catch {
    throw new Error(
      `Cannot read test project for ${packageName}: ${projectPath}`
    );
  }

  const project = JSON.parse(content) as {
    tree: { ServerScriptService?: RojoNode };
  };
  const sss = project.tree?.ServerScriptService;
  if (!sss) {
    throw new Error(
      `Test project for ${packageName} is missing ServerScriptService in tree`
    );
  }

  for (const key of Object.keys(sss)) {
    if (!key.startsWith('$') && key !== 'Script') {
      return key;
    }
  }

  throw new Error(
    `Test project for ${packageName} has no package entry under SSS`
  );
}
