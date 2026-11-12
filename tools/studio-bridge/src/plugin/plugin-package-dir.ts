import * as fs from 'fs';
import * as path from 'path';
import { resolvePackagePath } from '@quenty/nevermore-template-helpers/resolve-template-path';
import { StudioBridgeError } from '../messages/studio-bridge-error.js';

export const PLUGIN_PACKAGE_NAME = '@quenty/studio-bridge-plugin';
export const BUNDLED_PLUGIN_DIR_NAME = 'studio-bridge-plugin';

export function resolvePluginPackageDir(
  packageRoot: string,
  isPluginPackage: (dir: string) => boolean = isPluginPackageDir
): string {
  const candidates = [
    path.join(packageRoot, '..', '..', 'plugins', 'studio-bridge-plugin'),
    path.join(packageRoot, BUNDLED_PLUGIN_DIR_NAME),
  ];
  const found = candidates.find((dir) => isPluginPackage(dir));
  if (!found) {
    throw new StudioBridgeError({
      code: 'PLUGIN_MISSING',
      message: 'This studio-bridge install is missing its Studio plugin.',
      fix: "Run 'npm install -g @quenty/studio-bridge' to reinstall it.",
      cause: `Looked in ${candidates.join(' and ')}`,
    });
  }
  return found;
}

function isPluginPackageDir(dir: string): boolean {
  try {
    const packageJson = JSON.parse(
      fs.readFileSync(path.join(dir, 'package.json'), 'utf-8')
    ) as { name?: string };
    return packageJson.name === PLUGIN_PACKAGE_NAME;
  } catch {
    return false;
  }
}

let cachedDir: string | undefined;

export function getPluginPackageDir(): string {
  cachedDir ??= resolvePluginPackageDir(resolvePackagePath(import.meta.url));
  return cachedDir;
}
