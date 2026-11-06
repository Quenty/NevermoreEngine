import * as fs from 'fs/promises';
import * as path from 'path';
import * as tar from 'tar';
import { BuildContext } from '@quenty/nevermore-template-helpers';
import { PLACE_UPLOAD_MAX_BYTES } from '../open-cloud/open-cloud-client.js';
import {
  PACKAGE_NAME_PATTERN,
  readUntrustedTarAsync,
} from '../bundle/untrusted-tar.js';
import { type GitDeployInfo } from './deploy-metadata.js';

/**
 * Places built by `nevermore batch bundle --deploy`, unpacked from a
 * `*.nevermore.deploy.tar` and ready for `batch deploy --bundle` to deploy.
 *
 * Each place is the plain rojo build. Its base place is merged at deploy time,
 * because downloading one needs the Open Cloud key the building run lacks.
 */
export interface PrebuiltDeployBundle {
  /** Deploy target name the places were built for, e.g. "integration". */
  target: string;
  /** The commit the places were built from, not the deploying checkout's. */
  git: GitDeployInfo;
  places: PrebuiltDeployPlace[];
  /** Holds the unpacked files; whoever deploys them owns its cleanup. */
  buildContext: BuildContext;
}

export interface PrebuiltDeployPlace {
  /** Batch target display name, e.g. "@quenty/game" or "@quenty/game - hub". */
  name: string;
  rbxlPath: string;
  /** The building checkout's rojo project, which says what to graft onto the base place. */
  projectPath: string;
  packageVersion?: string;
}

interface ManifestFile {
  formatVersion: number;
  kind?: 'deploy';
  target: string;
  git: GitDeployInfo;
  places: Array<{
    name: string;
    file: string;
    project: string;
    packageVersion?: string;
  }>;
}

/** Suggested file suffix, following `deploy.nevermore.json`. */
export const DEPLOY_BUNDLE_FILE_SUFFIX = '.nevermore.deploy.tar';

const MANIFEST_FILE_NAME = 'manifest.json';
const FORMAT_VERSION = 1;
const MAX_PLACES = 64;
const MAX_MANIFEST_BYTES = 1024 * 1024;
const MAX_PROJECT_BYTES = 1024 * 1024;
const PLACE_FILE_PATTERN = /^place-\d{1,3}\.rbxl$/;
const PROJECT_FILE_PATTERN = /^project-\d{1,3}\.json$/;
const TARGET_NAME_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;
const SHORT_SHA_PATTERN = /^[0-9a-f]{4,40}$/;
const SHA_PATTERN = /^[0-9a-f]{40}$/;
const BRANCH_PATTERN = /^[A-Za-z0-9._/-]{1,200}$/;
const PACKAGE_VERSION_PATTERN = /^[0-9A-Za-z.+-]{1,64}$/;

export async function writePrebuiltDeployBundleAsync(
  file: string,
  target: string,
  git: GitDeployInfo,
  places: PrebuiltDeployPlace[]
): Promise<void> {
  const stage = await BuildContext.createAsync({ prefix: 'deploy-bundle-' });
  const stageDir = stage.buildDir;
  try {
    const manifest: ManifestFile = {
      formatVersion: FORMAT_VERSION,
      kind: 'deploy',
      target,
      git,
      places: [],
    };
    for (const [index, place] of places.entries()) {
      const placeFile = `place-${index + 1}.rbxl`;
      const projectFile = `project-${index + 1}.json`;
      await fs.copyFile(place.rbxlPath, path.join(stageDir, placeFile));
      await fs.copyFile(place.projectPath, path.join(stageDir, projectFile));
      manifest.places.push({
        name: place.name,
        file: placeFile,
        project: projectFile,
        packageVersion: place.packageVersion,
      });
    }
    await fs.writeFile(
      path.join(stageDir, MANIFEST_FILE_NAME),
      JSON.stringify(manifest, null, 2)
    );

    await fs.mkdir(path.dirname(path.resolve(file)), { recursive: true });
    await tar.c({ file, cwd: stageDir, portable: true }, [
      MANIFEST_FILE_NAME,
      ...manifest.places.flatMap((p) => [p.file, p.project]),
    ]);
  } finally {
    await stage.cleanupAsync();
  }
}

/**
 * Read a deploy bundle file. It is untrusted: it comes from a fork's CI run.
 * Entries are read rather than extracted, every manifest string is checked
 * before it can reach a place attribute or the PR comment, and the bundle
 * names places only by target name — where each one deploys, and which base
 * place it merges onto, come from the deploying checkout's config.
 */
export async function readPrebuiltDeployBundleAsync(
  file: string
): Promise<PrebuiltDeployBundle> {
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
    prefix: 'deploy-bundle-',
  });
  const dir = buildContext.buildDir;
  try {
    const { manifestText, entrySizes } = await readUntrustedTarAsync(
      file,
      dir,
      {
        kind: 'deploy',
        manifestName: MANIFEST_FILE_NAME,
        maxManifestBytes: MAX_MANIFEST_BYTES,
        isEntryAllowed: (name) =>
          PLACE_FILE_PATTERN.test(name) || PROJECT_FILE_PATTERN.test(name),
        maxEntries: MAX_PLACES * 2,
        maxEntriesMessage: `Bundle must hold at most ${MAX_PLACES} places`,
        checkEntrySize: (name, size) => {
          if (PLACE_FILE_PATTERN.test(name) && size > PLACE_UPLOAD_MAX_BYTES) {
            return `${name} is over the place upload limit`;
          }
          if (PROJECT_FILE_PATTERN.test(name) && size > MAX_PROJECT_BYTES) {
            return `${name} is over the project file size limit`;
          }
          return undefined;
        },
      }
    );
    const parsed = _parseManifest(manifestText, dir, entrySizes);
    for (const place of parsed.places) {
      await _validateProjectFileAsync(place.projectPath);
    }
    return { ...parsed, buildContext };
  } catch (err) {
    await buildContext.cleanupAsync();
    throw err;
  }
}

function _parseManifest(
  manifestText: string,
  dir: string,
  entrySizes: Map<string, number>
): Omit<PrebuiltDeployBundle, 'buildContext'> {
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
  if (
    typeof manifest.target !== 'string' ||
    !TARGET_NAME_PATTERN.test(manifest.target)
  ) {
    throw new Error(
      `Bundle lists an invalid target: ${String(manifest.target)}`
    );
  }
  if (!Array.isArray(manifest.places) || manifest.places.length > MAX_PLACES) {
    throw new Error(`Bundle must list at most ${MAX_PLACES} places`);
  }
  if (manifest.places.length * 2 !== entrySizes.size) {
    throw new Error('Bundle manifest does not list every file it holds');
  }

  const git = _parseGit(manifest.git);
  const seenNames = new Set<string>();
  const seenFiles = new Set<string>();
  const places: PrebuiltDeployPlace[] = [];

  for (const entry of manifest.places) {
    const { name, file, project, packageVersion } = entry ?? {};
    if (typeof name !== 'string' || !PACKAGE_NAME_PATTERN.test(name)) {
      throw new Error(`Bundle lists an invalid package name: ${String(name)}`);
    }
    if (seenNames.has(name)) {
      throw new Error(`Bundle lists ${name} more than once`);
    }
    seenNames.add(name);

    for (const [listed, pattern] of [
      [file, PLACE_FILE_PATTERN],
      [project, PROJECT_FILE_PATTERN],
    ] as const) {
      if (
        typeof listed !== 'string' ||
        !pattern.test(listed) ||
        !entrySizes.has(listed) ||
        seenFiles.has(listed)
      ) {
        throw new Error(
          `Bundle lists an invalid file for ${name}: ${String(listed)}`
        );
      }
      seenFiles.add(listed);
    }

    if (
      packageVersion !== undefined &&
      (typeof packageVersion !== 'string' ||
        !PACKAGE_VERSION_PATTERN.test(packageVersion))
    ) {
      throw new Error(`Bundle lists an invalid package version for ${name}`);
    }

    places.push({
      name,
      rbxlPath: path.join(dir, file!),
      projectPath: path.join(dir, project!),
      packageVersion,
    });
  }

  return { target: manifest.target, git, places };
}

function _parseGit(git: unknown): GitDeployInfo {
  if (git === undefined) {
    return {};
  }
  if (typeof git !== 'object' || git === null) {
    throw new Error('Bundle lists invalid git info');
  }
  const { commit, version, branch } = git as Record<string, unknown>;
  const result: GitDeployInfo = {};
  for (const [key, value, pattern] of [
    ['commit', commit, SHORT_SHA_PATTERN],
    ['version', version, SHA_PATTERN],
  ] as const) {
    if (value === undefined) {
      continue;
    }
    if (typeof value !== 'string' || !pattern.test(value)) {
      throw new Error(`Bundle lists an invalid git ${key}`);
    }
    result[key] = value;
  }
  // Git allows branch names this pattern does not, and a branch is only a
  // label, so one that fails it is dropped rather than failing the deploy.
  if (typeof branch === 'string' && BRANCH_PATTERN.test(branch)) {
    result.branch = branch;
  }
  return result;
}

async function _validateProjectFileAsync(projectPath: string): Promise<void> {
  let project: unknown;
  try {
    project = JSON.parse(await fs.readFile(projectPath, 'utf-8'));
  } catch {
    throw new Error(
      `Bundle project ${path.basename(projectPath)} is not valid JSON`
    );
  }
  const tree = (project as { tree?: unknown })?.tree;
  if (typeof tree !== 'object' || tree === null) {
    throw new Error(
      `Bundle project ${path.basename(projectPath)} has no "tree"`
    );
  }
}
