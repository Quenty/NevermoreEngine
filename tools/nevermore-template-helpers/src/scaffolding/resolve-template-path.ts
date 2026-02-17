import * as path from 'path';
import * as fs from 'fs';
import { fileURLToPath } from 'url';

/**
 * Resolve a template path relative to the calling package's `templates/` directory.
 *
 * @param callerUrl - Pass `import.meta.url` from the calling module
 * @param name - Template name (can include subdirectory, e.g. 'default-test-place/default.project.json')
 */
export function resolveTemplatePath(callerUrl: string, name: string): string {
  const callerDir = path.dirname(fileURLToPath(callerUrl));
  const packageRoot = findPackageRoot(callerDir);
  return path.join(packageRoot, 'templates', name);
}

/**
 * Resolve a path relative to the calling package's root directory.
 *
 * @param callerUrl - Pass `import.meta.url` from the calling module
 * @param segments - Path segments to join (e.g. 'build-scripts', 'transform.luau')
 */
export function resolvePackagePath(callerUrl: string, ...segments: string[]): string {
  const callerDir = path.dirname(fileURLToPath(callerUrl));
  const packageRoot = findPackageRoot(callerDir);
  return path.join(packageRoot, ...segments);
}

function findPackageRoot(startDir: string): string {
  let dir = startDir;
  while (true) {
    if (fs.existsSync(path.join(dir, 'package.json'))) {
      return dir;
    }
    const parent = path.dirname(dir);
    if (parent === dir) {
      throw new Error(`Could not find package.json above ${startDir}`);
    }
    dir = parent;
  }
}
