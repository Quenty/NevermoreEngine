/**
 * Builds a minimal .rbxl place file via rojo for use when no place is
 * provided. The place just has ServerScriptService with LoadStringEnabled
 * so that loadstring() works in the injected plugin.
 */

import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { rojoBuildAsync, resolveTemplatePath } from '@quenty/nevermore-template-helpers';

const projectPath = resolveTemplatePath(
  import.meta.url,
  path.join('default-test-place', 'default.project.json')
);

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

  OutputHelper.verbose(
    `[StudioBridge] Building minimal place in ${tmpDir}`
  );

  try {
    const placePath = path.join(tmpDir, 'minimal.rbxl');
    await rojoBuildAsync({ projectPath, output: placePath });

    OutputHelper.verbose(`[StudioBridge] Minimal place built: ${placePath}`);

    return {
      placePath,
      cleanupAsync: async () => {
        try {
          await fs.rm(tmpDir, { recursive: true, force: true });
        } catch {
          // best effort
        }
      },
    };
  } catch (err) {
    try {
      await fs.rm(tmpDir, { recursive: true, force: true });
    } catch {
      // best effort
    }

    const message = err instanceof Error ? err.message : String(err);
    throw new Error(
      `Failed to build minimal place via rojo. Is rojo installed and on PATH?\n${message}`
    );
  }
}
