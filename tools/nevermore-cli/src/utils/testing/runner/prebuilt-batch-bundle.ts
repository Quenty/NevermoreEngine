import * as fs from 'fs/promises';
import * as path from 'path';
import * as tar from 'tar';
import { BuildContext } from '@quenty/nevermore-template-helpers';
import { type CombinedPlaceChunk } from './combined-project-generator.js';
import { PLACE_UPLOAD_MAX_BYTES } from '../../open-cloud/open-cloud-client.js';
import {
  PACKAGE_NAME_PATTERN,
  readUntrustedTarAsync,
} from '../../bundle/untrusted-tar.js';

/**
 * Places built by `nevermore batch bundle --test`, unpacked from a
 * `*.nevermore.tests.tar` and ready for `batch test --bundle` to run.
 */
export interface PrebuiltBatchBundle {
  chunks: CombinedPlaceChunk[];
  packages: PrebuiltBatchPackage[];
  /** Holds the unpacked places; whoever runs them owns its cleanup. */
  buildContext: BuildContext;
}

export interface PrebuiltBatchPackage {
  name: string;
  hasJestConfig: boolean;
}

interface ManifestFile {
  formatVersion: number;
  kind?: 'tests';
  chunks: Array<{
    file: string;
    packages: Array<{ name: string; slug: string; hasJestConfig: boolean }>;
  }>;
}

/** Suggested file suffix, following `deploy.nevermore.json`. */
export const BUNDLE_FILE_SUFFIX = '.nevermore.tests.tar';

const MANIFEST_FILE_NAME = 'manifest.json';
const FORMAT_VERSION = 1;
const MAX_CHUNKS = 32;
const MAX_PACKAGES = 1000;
const MAX_MANIFEST_BYTES = 1024 * 1024;
const CHUNK_FILE_PATTERN = /^place-\d{1,3}\.rbxl$/;
const SLUG_PATTERN = /^[A-Za-z0-9_.-]{1,100}$/;

export async function writePrebuiltBatchBundleAsync(
  file: string,
  chunks: CombinedPlaceChunk[],
  hasJestConfig: Map<string, boolean>
): Promise<void> {
  const stage = await BuildContext.createAsync({ prefix: 'test-bundle-' });
  const stageDir = stage.buildDir;
  try {
    const manifest: ManifestFile = {
      formatVersion: FORMAT_VERSION,
      kind: 'tests',
      chunks: [],
    };
    for (const [index, chunk] of chunks.entries()) {
      const placeFile = `place-${index + 1}.rbxl`;
      await fs.copyFile(chunk.rbxlPath, path.join(stageDir, placeFile));
      manifest.chunks.push({
        file: placeFile,
        packages: [...chunk.slugMap].map(([name, slug]) => ({
          name,
          slug,
          hasJestConfig: hasJestConfig.get(name) ?? false,
        })),
      });
    }
    await fs.writeFile(
      path.join(stageDir, MANIFEST_FILE_NAME),
      JSON.stringify(manifest, null, 2)
    );

    await fs.mkdir(path.dirname(path.resolve(file)), { recursive: true });
    await tar.c({ file, cwd: stageDir, portable: true }, [
      MANIFEST_FILE_NAME,
      ...manifest.chunks.map((c) => c.file),
    ]);
  } finally {
    await stage.cleanupAsync();
  }
}

/**
 * Read a bundle file. It is untrusted: entries are read from the archive, never
 * extracted by it, and only `manifest.json` and `place-N.rbxl` regular files
 * are accepted.
 */
export async function readPrebuiltBatchBundleAsync(
  file: string
): Promise<PrebuiltBatchBundle> {
  let stat;
  try {
    stat = await fs.lstat(file);
  } catch {
    throw new Error(`Bundle file not found: ${file}`);
  }
  if (!stat.isFile()) {
    throw new Error(`Bundle ${file} is not a regular file`);
  }

  const buildContext = await BuildContext.createAsync({
    prefix: 'test-bundle-',
  });
  const dir = buildContext.buildDir;
  try {
    const { manifestText, entrySizes: placeSizes } =
      await readUntrustedTarAsync(file, dir, {
        kind: 'tests',
        manifestName: MANIFEST_FILE_NAME,
        maxManifestBytes: MAX_MANIFEST_BYTES,
        isEntryAllowed: (name) => CHUNK_FILE_PATTERN.test(name),
        maxEntries: MAX_CHUNKS,
        maxEntriesMessage: `Bundle must hold at most ${MAX_CHUNKS} places`,
        checkEntrySize: (name, size) =>
          size > PLACE_UPLOAD_MAX_BYTES
            ? `${name} is over the place upload limit`
            : undefined,
      });
    return { ..._parseManifest(manifestText, dir, placeSizes), buildContext };
  } catch (err) {
    await buildContext.cleanupAsync();
    throw err;
  }
}

function _parseManifest(
  manifestText: string,
  dir: string,
  placeSizes: Map<string, number>
): { chunks: CombinedPlaceChunk[]; packages: PrebuiltBatchPackage[] } {
  let parsed: unknown;
  try {
    parsed = JSON.parse(manifestText);
  } catch {
    throw new Error('Bundle manifest is not valid JSON');
  }

  const manifest = parsed as Partial<ManifestFile>;
  if (manifest?.formatVersion !== FORMAT_VERSION) {
    throw new Error(
      `Unsupported bundle format ${String(manifest?.formatVersion)} ` +
        `(expected ${FORMAT_VERSION})`
    );
  }
  if (!Array.isArray(manifest.chunks) || manifest.chunks.length > MAX_CHUNKS) {
    throw new Error(`Bundle must list at most ${MAX_CHUNKS} places`);
  }
  if (manifest.chunks.length !== placeSizes.size) {
    throw new Error('Bundle manifest does not list every place it holds');
  }

  const seenNames = new Set<string>();
  const seenSlugs = new Set<string>();
  const seenFiles = new Set<string>();
  const chunks: CombinedPlaceChunk[] = [];
  const packages: PrebuiltBatchPackage[] = [];

  for (const entry of manifest.chunks) {
    const file = entry?.file;
    const sizeBytes =
      typeof file === 'string' ? placeSizes.get(file) : undefined;
    if (sizeBytes === undefined || seenFiles.has(file!)) {
      throw new Error(`Bundle lists an invalid place file: ${String(file)}`);
    }
    seenFiles.add(file!);

    if (!Array.isArray(entry.packages) || entry.packages.length === 0) {
      throw new Error(`${file} lists no packages`);
    }

    const slugMap = new Map<string, string>();
    for (const pkg of entry.packages) {
      const { name, slug, hasJestConfig } = pkg ?? {};
      if (typeof name !== 'string' || !PACKAGE_NAME_PATTERN.test(name)) {
        throw new Error(
          `Bundle lists an invalid package name: ${String(name)}`
        );
      }
      if (typeof slug !== 'string' || !SLUG_PATTERN.test(slug)) {
        throw new Error(`Bundle lists an invalid slug for ${name}`);
      }
      if (seenNames.has(name) || seenSlugs.has(slug)) {
        throw new Error(`Bundle lists ${name} (${slug}) more than once`);
      }
      seenNames.add(name);
      seenSlugs.add(slug);
      slugMap.set(name, slug);
      packages.push({ name, hasJestConfig: hasJestConfig === true });
    }

    chunks.push({ rbxlPath: path.join(dir, file!), slugMap, sizeBytes });
  }

  if (packages.length > MAX_PACKAGES) {
    throw new Error(`Bundle lists more than ${MAX_PACKAGES} packages`);
  }

  return { chunks, packages };
}
