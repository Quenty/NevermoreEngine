import * as fs from 'fs/promises';
import * as path from 'path';
import {
  BuildContext,
  resolvePackagePath,
} from '@quenty/nevermore-template-helpers';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { type DeployTarget } from '@quenty/nevermore-deploy';
import { type BatchTarget } from '../../batch/changed-packages-utils.js';
import { recompressPlace } from '../../build/place-recompression.js';

/**
 * Budget for one combined place, as uploaded (recompressed). Under the upload
 * limit (`PLACE_UPLOAD_MAX_BYTES`), and under the 100 MB Roblox documents as
 * supported, since split places run in parallel and cost little.
 */
export const DEFAULT_MAX_CHUNK_BYTES = 90 * 1024 * 1024;

/** One combined place: the packages that are uploaded and executed together. */
export interface CombinedPlaceChunk {
  /** Absolute path to this chunk's combined .rbxl file. */
  rbxlPath: string;
  /** batchTarget.name → ServerScriptService slug, for this chunk's packages only. */
  slugMap: Map<string, string>;
  /** Size on disk — recompressed whenever the batch has a size budget. */
  sizeBytes: number;
}

export interface CombinedProjectResult {
  /**
   * The combined places, in package order. Usually one; more when even
   * recompressed the packages together exceed the per-upload budget.
   */
  chunks: CombinedPlaceChunk[];
  /** batchTarget.name → ServerScriptService slug mapping, across every chunk. */
  slugMap: Map<string, string>;
  /** First batch target's deploy target (provides placeId/universeId for upload). */
  primaryTarget: DeployTarget;
  /** Owns the temp directory — caller must clean up via buildContext.cleanupAsync(). */
  buildContext: BuildContext;
}

interface RojoNode {
  [key: string]: unknown;
}

import { type StepProgress } from '@quenty/cli-output-helpers/reporting';

/** Progress callbacks for granular phase reporting during combined builds. */
export interface CombinedBuildProgress {
  onPackageBuildStart?(packageName: string): void;
  onPackageBuildComplete?(packageName: string): void;
  onCombineStart?(): void;
  onStepProgress?(progress: StepProgress): void;
}

/** Per-package build info collected during phase 1. */
interface PackageBuildInfo {
  name: string;
  slug: string;
  rbxlPath: string;
  scriptPath: string;
  sizeBytes: number;
}

/**
 * Build combined .rbxl files containing all testable packages.
 *
 * Two-phase approach to avoid rojo's symlink deduplication:
 *   Phase 1: Build each package's .rbxl individually via rojo
 *   Phase 2: Use Lune to merge the individual builds into one place, split
 *            into more only if it measures over `maxChunkBytes`
 */
export async function generateCombinedProjectAsync(options: {
  batchTargets: BatchTarget[];
  repoRoot: string;
  batchPlaceId?: number;
  batchUniverseId?: number;
  maxChunkBytes?: number;
  progress?: CombinedBuildProgress;
}): Promise<CombinedProjectResult> {
  const {
    batchTargets,
    batchPlaceId,
    batchUniverseId,
    maxChunkBytes = DEFAULT_MAX_CHUNK_BYTES,
    progress,
  } = options;

  if (batchTargets.length === 0) {
    throw new Error(
      'No batch targets provided for combined project generation'
    );
  }

  const buildContext = await BuildContext.createAsync({
    prefix: 'batch-project-',
  });

  const slugMap = new Map<string, string>();
  const firstTarget = batchTargets[0]!.target;
  const primaryTarget: DeployTarget = { ...firstTarget };
  if (batchPlaceId) primaryTarget.placeId = batchPlaceId;
  if (batchUniverseId) primaryTarget.universeId = batchUniverseId;

  const builds: PackageBuildInfo[] = [];

  // ── Phase 1: Build each batch target individually ──

  let buildIndex = 0;
  for (const buildTarget of batchTargets) {
    const { target } = buildTarget;

    // Parse the rojo project to extract the ServerScriptService slug
    const projectPath = path.resolve(buildTarget.path, target.project);
    const slug = await _extractSlugAsync(buildTarget.name, projectPath);

    // Validate slug uniqueness
    for (const [existingName, existingSlug] of slugMap) {
      if (existingSlug === slug) {
        throw new Error(
          `Slug collision: ${buildTarget.name} and ${existingName} both use slug "${slug}"`
        );
      }
    }
    slugMap.set(buildTarget.name, slug);

    // Build this target's .rbxl
    const rbxlPath = buildContext.resolvePath(`${slug}.rbxl`);
    OutputHelper.verbose(`Building ${buildTarget.name} (${slug})...`);
    progress?.onPackageBuildStart?.(buildTarget.name);
    await buildContext.rojoBuildAsync({ projectPath, output: rbxlPath });
    buildIndex++;
    progress?.onPackageBuildComplete?.(buildTarget.name);
    progress?.onStepProgress?.({
      kind: 'steps',
      completed: buildIndex,
      total: batchTargets.length,
      label: buildTarget.name,
    });

    // Resolve scriptTemplate path
    if (!target.scriptTemplate) {
      throw new Error(
        `No scriptTemplate for ${buildTarget.name} — required for batch testing`
      );
    }
    const scriptPath = path.resolve(buildTarget.path, target.scriptTemplate);

    const { size: sizeBytes } = await fs.stat(rbxlPath);

    builds.push({
      name: buildTarget.name,
      slug,
      rbxlPath,
      scriptPath,
      sizeBytes,
    });
  }

  // ── Phase 2: Merge via Lune ──

  const luneScriptPath = resolvePackagePath(
    import.meta.url,
    'build-scripts',
    'combine-test-places.lua'
  );

  progress?.onCombineStart?.();

  // One place first, split only if it measures over budget. Sizes do not add
  // up: recompression dedupes the modules the packages share, so a merge of
  // many packages costs little more than one, and only measuring it says so.
  const totalBytes = builds.reduce((sum, b) => sum + b.sizeBytes, 0);
  let groups = [builds];
  let chunks: CombinedPlaceChunk[];
  for (;;) {
    chunks = await _mergeGroupsAsync(
      buildContext,
      luneScriptPath,
      groups,
      Number.isFinite(maxChunkBytes),
      progress
    );

    const largest = Math.max(...chunks.map((c) => c.sizeBytes));
    if (largest <= maxChunkBytes || groups.length === builds.length) {
      break;
    }

    const groupCount = Math.max(
      groups.length + 1,
      Math.ceil((groups.length * largest) / maxChunkBytes)
    );
    OutputHelper.info(
      `Combined place${groups.length === 1 ? ' is' : 's reach'} ` +
        `${formatMegabytes(largest)}, over the ${formatMegabytes(
          maxChunkBytes
        )} per-upload budget — splitting ${builds.length} targets into ` +
        `about ${groupCount} places.`
    );
    groups = partitionBySize(
      builds,
      (b) => b.sizeBytes,
      totalBytes / groupCount
    );
  }

  return {
    chunks,
    slugMap,
    primaryTarget,
    buildContext,
  };
}

/**
 * Merge each group into its own place, recompressed when it will be measured
 * against a budget — which is also the form it is uploaded in, so the upload
 * has nothing left to do.
 */
async function _mergeGroupsAsync(
  buildContext: BuildContext,
  luneScriptPath: string,
  groups: PackageBuildInfo[][],
  recompress: boolean,
  progress: CombinedBuildProgress | undefined
): Promise<CombinedPlaceChunk[]> {
  progress?.onStepProgress?.({
    kind: 'steps',
    completed: 0,
    total: groups.length,
  });

  const chunks: CombinedPlaceChunk[] = [];
  for (const [index, group] of groups.entries()) {
    const combinedRbxlPath = buildContext.resolvePath(
      groups.length === 1 ? 'batch-test.rbxl' : `batch-test-${index + 1}.rbxl`
    );

    // Build args: <outputPath> <slug1> <rbxl1> <script1> <slug2> <rbxl2> <script2> ...
    const luneArgs: string[] = [combinedRbxlPath];
    for (const build of group) {
      luneArgs.push(build.slug, build.rbxlPath, build.scriptPath);
    }

    OutputHelper.verbose(
      `Merging ${group.length} targets into ${path.basename(
        combinedRbxlPath
      )}...`
    );
    await buildContext.executeLuneTransformScriptAsync(
      luneScriptPath,
      ...luneArgs
    );

    let sizeBytes: number;
    if (recompress) {
      const merged = await fs.readFile(combinedRbxlPath);
      const result = recompressPlace(merged);
      if (result.kind === 'recompressed') {
        await fs.writeFile(combinedRbxlPath, result.data);
      }
      sizeBytes = result.data.length;
      OutputHelper.verbose(
        `Combined ${group.length} targets at ${combinedRbxlPath} ` +
          `(${formatMegabytes(merged.length)} as built, ` +
          `${formatMegabytes(sizeBytes)} to upload)`
      );
    } else {
      ({ size: sizeBytes } = await fs.stat(combinedRbxlPath));
      OutputHelper.verbose(
        `Combined ${
          group.length
        } targets at ${combinedRbxlPath} (${formatMegabytes(sizeBytes)})`
      );
    }

    chunks.push({
      rbxlPath: combinedRbxlPath,
      slugMap: new Map(group.map((b) => [b.name, b.slug])),
      sizeBytes,
    });
    progress?.onStepProgress?.({
      kind: 'steps',
      completed: index + 1,
      total: groups.length,
    });
  }

  return chunks;
}

/**
 * Split items, in order, into consecutive groups whose summed size stays within
 * `maxBytes`. An item larger than the budget on its own gets a group to itself
 * rather than being dropped — the upload is what reports it as too big.
 */
export function partitionBySize<T>(
  items: T[],
  sizeOf: (item: T) => number,
  maxBytes: number
): T[][] {
  const groups: T[][] = [];
  let current: T[] = [];
  let currentBytes = 0;

  for (const item of items) {
    const size = sizeOf(item);
    if (current.length > 0 && currentBytes + size > maxBytes) {
      groups.push(current);
      current = [];
      currentBytes = 0;
    }
    current.push(item);
    currentBytes += size;
  }

  if (current.length > 0) {
    groups.push(current);
  }

  return groups;
}

/** In Roblox's MB, which are 1024 * 1024 bytes. */
export function formatMegabytes(bytes: number): string {
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

/**
 * Extract the slug from a test rojo project.
 * The slug is the first non-`$`, non-`Script` key under ServerScriptService.
 */
async function _extractSlugAsync(
  batchTargetName: string,
  projectPath: string
): Promise<string> {
  let content: string;
  try {
    content = await fs.readFile(projectPath, 'utf-8');
  } catch {
    throw new Error(
      `Cannot read test project for ${batchTargetName}: ${projectPath}`
    );
  }

  const project = JSON.parse(content) as {
    tree: { ServerScriptService?: RojoNode };
  };
  const serverScriptService = project.tree?.ServerScriptService;
  if (!serverScriptService) {
    throw new Error(
      `Test project for ${batchTargetName} is missing ServerScriptService in tree`
    );
  }

  for (const key of Object.keys(serverScriptService)) {
    if (!key.startsWith('$') && key !== 'Script') {
      return key;
    }
  }

  throw new Error(
    `Test project for ${batchTargetName} has no entry under ServerScriptService`
  );
}
