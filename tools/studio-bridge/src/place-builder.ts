/**
 * Builds a minimal .rbxl place file via rojo for use when no place is
 * provided. The place just has ServerScriptService with LoadStringEnabled
 * so that loadstring() works in the injected plugin.
 */

import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { execa } from 'execa';
import { OutputHelper } from '@quenty/cli-output-helpers';

const MINIMAL_PROJECT = {
  name: 'StudioBridgeMinimal',
  tree: {
    $className: 'DataModel',
    ServerScriptService: {
      $properties: {
        LoadStringEnabled: true,
      },
    },
  },
};

export interface BuiltPlace {
  /** Absolute path to the .rbxl file */
  placePath: string;
  /** Remove the temp directory (idempotent) */
  cleanupAsync: () => Promise<void>;
}

/**
 * Build a minimal .rbxl place file in a temp directory using rojo.
 */
export async function buildMinimalPlaceAsync(): Promise<BuiltPlace> {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'studio-bridge-'));
  const projectPath = path.join(tmpDir, 'default.project.json');
  const placePath = path.join(tmpDir, 'minimal.rbxl');

  await fs.writeFile(projectPath, JSON.stringify(MINIMAL_PROJECT, null, 2), 'utf-8');

  OutputHelper.verbose(`[StudioBridge] Building minimal place in ${tmpDir}`);

  try {
    await execa('rojo', ['build', '-o', placePath], { cwd: tmpDir });
  } catch (err) {
    // Clean up on build failure
    await fs.rm(tmpDir, { recursive: true, force: true }).catch(() => {});

    const message = err instanceof Error ? err.message : String(err);
    throw new Error(
      `Failed to build minimal place via rojo. Is rojo installed and on PATH?\n${message}`
    );
  }

  OutputHelper.verbose(`[StudioBridge] Minimal place built: ${placePath}`);

  let cleaned = false;
  const cleanupAsync = async () => {
    if (cleaned) return;
    cleaned = true;
    try {
      await fs.rm(tmpDir, { recursive: true, force: true });
    } catch {
      // best effort
    }
  };

  return { placePath, cleanupAsync };
}
