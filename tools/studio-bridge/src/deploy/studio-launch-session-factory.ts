/**
 * Studio sessions that open a copy of a built place and leave Studio open.
 * The copy is marked with the target's place and universe ids, which the
 * plugin applies (`SetPlaceId` is plugin-only).
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { execa } from 'execa';
import { resolvePackagePath } from '@quenty/nevermore-template-helpers/resolve-template-path';
import {
  type StudioSession,
  type StudioSessionFactory,
} from '@quenty/nevermore-job-helpers';
import { getStateDir } from '../state-dir.js';
import { launchAndRecordStudioAsync } from '../process/launch-and-record-studio.js';
import { readStudioLaunchesAsync } from '../process/studio-launch-registry.js';
import { isProcessRunning } from '../process/studio-process-closer.js';

/** Copies whose Studio can't be identified are deleted after this long. */
const BUILT_PLACE_MAX_AGE_MS = 24 * 60 * 60 * 1000;

const PLACE_IDENTITY_TRANSFORM_SCRIPT = resolvePackagePath(
  import.meta.url,
  'build-scripts',
  'transform-add-place-identity.lua'
);

export interface StudioLaunchSessionFactoryOptions {
  selector: string;
  cwd?: string;
  placeIdentity: { placeId: number; universeId: number };
}

export interface StudioLaunchSession extends StudioSession {
  placePath: string;
  stateDir: string;
}

export function createStudioLaunchSessionFactory(
  options: StudioLaunchSessionFactoryOptions
): StudioSessionFactory<StudioLaunchSession> {
  return {
    async startSessionAsync({ placePath, onPhase }) {
      // The job deletes its build when the session ends; Studio keeps a copy.
      const copy = await _copyPlaceAsync(placePath, options);

      onPhase?.('launching');
      try {
        await launchAndRecordStudioAsync(
          { placePath: copy.placePath },
          {
            opened: `'${options.selector}' (local build)`,
            deployTarget: options.selector,
            placeDir: copy.stateDir,
          },
          options.cwd
        );
      } catch (err) {
        await fs.rm(copy.stateDir, { recursive: true, force: true });
        throw err;
      }

      return {
        ...copy,
        // Studio stays open.
        endAsync: async () => {},
      };
    },
  };
}

export type BuiltPlaceState = 'open' | 'closed' | 'unknown';

/**
 * Delete built places whose Studio has closed, or that are a day old and whose
 * Studio can't be identified.
 */
export async function pruneBuiltPlacesAsync(
  options: {
    root?: string;
    now?: number;
    getStateAsync?: (dir: string) => Promise<BuiltPlaceState>;
  } = {}
): Promise<void> {
  const root = options.root ?? _builtPlacesDir();
  const now = options.now ?? Date.now();
  const getStateAsync = options.getStateAsync ?? _getBuiltPlaceStateAsync;
  let entries: string[];
  try {
    entries = await fs.readdir(root);
  } catch {
    return;
  }

  for (const entry of entries) {
    const dir = path.join(root, entry);
    try {
      const state = await getStateAsync(dir);
      if (state === 'open') {
        continue;
      }
      if (state === 'unknown') {
        const stat = await fs.stat(dir);
        if (now - stat.mtimeMs <= BUILT_PLACE_MAX_AGE_MS) {
          continue;
        }
      }
      await fs.rm(dir, { recursive: true, force: true });
    } catch {
      // Locked or already gone; the next build tries again.
    }
  }
}

async function _copyPlaceAsync(
  placePath: string,
  options: StudioLaunchSessionFactoryOptions
): Promise<{ placePath: string; stateDir: string }> {
  await pruneBuiltPlacesAsync();
  const stateDir = path.join(_builtPlacesDir(), randomUUID());
  const copyPath = path.join(
    stateDir,
    `${_fileNameFor(options.selector)}.rbxl`
  );
  await fs.mkdir(stateDir, { recursive: true });
  try {
    await execa('lune', [
      'run',
      PLACE_IDENTITY_TRANSFORM_SCRIPT,
      placePath,
      copyPath,
      String(options.placeIdentity.placeId),
      String(options.placeIdentity.universeId),
    ]);
  } catch (err) {
    await fs.rm(stateDir, { recursive: true, force: true });
    throw err;
  }
  return { placePath: copyPath, stateDir };
}

function _builtPlacesDir(): string {
  return path.join(getStateDir(), 'places');
}

async function _getBuiltPlaceStateAsync(dir: string): Promise<BuiltPlaceState> {
  const records = await readStudioLaunchesAsync();
  const record = records.find((r) => r.placeDir === dir);
  if (!record || record.pid === undefined) {
    return 'unknown';
  }
  return isProcessRunning(record.pid) ? 'open' : 'closed';
}

function _fileNameFor(selector: string): string {
  return selector.replace(/[^A-Za-z0-9._-]/g, '_');
}
