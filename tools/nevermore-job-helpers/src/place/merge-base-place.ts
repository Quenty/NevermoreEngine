import * as fs from 'fs/promises';
import {
  BuildContext,
  resolvePackagePath,
} from '@quenty/nevermore-template-helpers';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import {
  type BasePlaceConfig,
  type BasePlaceResolver,
} from '@quenty/nevermore-deploy';

const MERGE_SCRIPT_PATH = resolvePackagePath(
  import.meta.url,
  'build-scripts',
  'transform-rojo-merge-place.lua'
);

/** Satisfied structurally by `OpenCloudPlaceClient`. */
export interface PlaceDownloader {
  downloadPlaceAsync(
    universeId: number,
    placeId: number,
    onProgress?: (transferredBytes: number, totalBytes: number) => void,
    version?: number
  ): Promise<Buffer>;
}

export interface MergeBasePlaceOptions {
  codeRbxlPath: string;
  basePlace: BasePlaceConfig;
  projectPath: string;
  packagePath: string;
  resolver: BasePlaceResolver;
  downloader: PlaceDownloader;
  reporter: Reporter;
  packageName: string;
}

export interface MergedPlace {
  rbxlPath: string;
  basePlaceVersion: number;
  /** Owns `rbxlPath`; the caller cleans it up. */
  buildContext: BuildContext;
}

/**
 * Download the base place a target names and graft a code build onto it.
 *
 * Every pin — number, keyword, or absent — becomes a concrete version here,
 * both because the Asset Delivery API only addresses versions numerically and
 * so the lock file records exactly what this build merged against.
 */
export async function mergeBasePlaceAsync(
  options: MergeBasePlaceOptions
): Promise<MergedPlace> {
  const { basePlace, reporter, packageName } = options;

  // Merge artifacts (base.rbxl, merged.rbxl) are per-place — siblings sharing
  // the rojo build would otherwise collide on filenames in one dir.
  const mergeContext = await BuildContext.createAsync({
    prefix: 'rojo-merge-',
  });

  try {
    reporter.onPackagePhaseChange(packageName, 'downloading');

    const version = await options.resolver.resolveAsync(
      options.packagePath,
      basePlace
    );
    OutputHelper.verbose(
      typeof basePlace.version === 'number'
        ? `Downloading base place (pinned v${version}) for merge...`
        : `Downloading base place (${
            basePlace.version ?? 'published'
          } → v${version}) for merge...`
    );

    const buffer = await options.downloader.downloadPlaceAsync(
      basePlace.universeId,
      basePlace.placeId,
      (transferred, total) => {
        reporter.onPackageProgressUpdate(packageName, {
          kind: 'bytes',
          transferredBytes: transferred,
          totalBytes: total,
        });
      },
      version
    );
    const basePath = mergeContext.resolvePath('base.rbxl');
    await fs.writeFile(basePath, buffer);

    reporter.onPackagePhaseChange(packageName, 'merging');
    const mergedPath = mergeContext.resolvePath('merged.rbxl');
    await mergeContext.executeLuneTransformScriptAsync(
      MERGE_SCRIPT_PATH,
      basePath,
      options.codeRbxlPath,
      options.projectPath,
      mergedPath
    );

    return {
      rbxlPath: mergedPath,
      basePlaceVersion: version,
      buildContext: mergeContext,
    };
  } catch (err) {
    await mergeContext.cleanupAsync().catch(() => {});
    throw err;
  }
}
