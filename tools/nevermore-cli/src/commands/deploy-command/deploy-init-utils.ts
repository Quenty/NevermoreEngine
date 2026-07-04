import * as fs from 'fs/promises';
import * as path from 'path';
import { fileExistsAsync } from '../../utils/nevermore-cli-utils.js';

/**
 * Auto-detects the default deploy target name for a package.
 *
 * A package whose root `default.project.json` defines a full place
 * (`tree.$className === "DataModel"`) is treated as a game and defaults
 * to "integration". Otherwise (library — with or without a `test/` folder)
 * defaults to "test".
 */
export async function detectTargetNameAsync(
  packagePath: string
): Promise<'test' | 'integration'> {
  if (await _isRootProjectDataModelAsync(packagePath)) {
    return 'integration';
  }
  return 'test';
}

async function _isRootProjectDataModelAsync(
  packagePath: string
): Promise<boolean> {
  const rootProject = path.join(packagePath, 'default.project.json');
  try {
    const content = await fs.readFile(rootProject, 'utf-8');
    const parsed = JSON.parse(content) as { tree?: { $className?: string } };
    return parsed.tree?.$className === 'DataModel';
  } catch {
    return false;
  }
}

export async function detectProjectFileAsync(
  packagePath: string
): Promise<string | undefined> {
  const candidates = [
    path.join(packagePath, 'test', 'default.project.json'),
    path.join(packagePath, 'default.project.json'),
  ];

  for (const candidate of candidates) {
    if (await fileExistsAsync(candidate)) {
      return path.relative(packagePath, candidate).replace(/\\/g, '/');
    }
  }

  return undefined;
}

export async function detectScriptFileAsync(
  packagePath: string
): Promise<string | undefined> {
  const candidates = [
    'test/scripts/Server/ServerMain.server.lua',
    'test/scripts/Server/ServerMain.server.luau',
    'scripts/Server/ServerMain.server.lua',
    'scripts/Client/ClientMain.server.luau',
  ];
  for (const candidate of candidates) {
    if (await fileExistsAsync(path.join(packagePath, candidate))) {
      return candidate;
    }
  }
  return undefined;
}
