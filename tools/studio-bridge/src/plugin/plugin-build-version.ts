/**
 * The plugin reports a hash of the sources it was built from as its
 * `pluginVersion`, so the CLI can tell when the installed plugin is stale.
 */

import { createHash } from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';
import { getPluginPackageDir } from './plugin-package-dir.js';

let cachedVersion: Promise<string> | undefined;

export function getPluginBuildVersionAsync(): Promise<string> {
  cachedVersion ??= hashPluginPackageAsync(getPluginPackageDir());
  return cachedVersion;
}

export async function hashPluginPackageAsync(
  packageDir: string
): Promise<string> {
  const roots: Array<{ label: string; dir: string }> = [
    { label: '', dir: packageDir },
  ];
  for (const dependency of await readDependencyNamesAsync(packageDir)) {
    roots.push({
      label: dependency,
      dir: await fs.realpath(path.join(packageDir, 'node_modules', dependency)),
    });
  }

  const hash = createHash('sha256');
  for (const { label, dir } of roots) {
    const files = await listPackageFilesAsync(dir);
    files.sort();
    for (const relativePath of files) {
      const contents = await fs.readFile(path.join(dir, relativePath), 'utf-8');
      hash.update(path.posix.join(label, relativePath.replace(/\\/g, '/')));
      hash.update('\0');
      hash.update(contents.replace(/\r\n/g, '\n'));
      hash.update('\0');
    }
  }
  return hash.digest('hex').slice(0, 12);
}

async function readDependencyNamesAsync(packageDir: string): Promise<string[]> {
  const packageJson = JSON.parse(
    await fs.readFile(path.join(packageDir, 'package.json'), 'utf-8')
  ) as { dependencies?: Record<string, string> };
  return Object.keys(packageJson.dependencies ?? {}).sort();
}

async function listPackageFilesAsync(packageDir: string): Promise<string[]> {
  const files: string[] = [];
  const projectPath = path.join(packageDir, 'default.project.json');
  if (await existsAsync(projectPath)) {
    files.push('default.project.json');
  }
  const srcDir = path.join(packageDir, 'src');
  if (await existsAsync(srcDir)) {
    files.push(...(await listSourceFilesAsync(packageDir, srcDir)));
  }
  return files;
}

async function listSourceFilesAsync(
  baseDir: string,
  currentDir: string
): Promise<string[]> {
  const entries = await fs.readdir(currentDir, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const fullPath = path.join(currentDir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'node_modules') {
        files.push(...(await listSourceFilesAsync(baseDir, fullPath)));
      }
    } else if (
      entry.isFile() &&
      !entry.name.endsWith('.spec.lua') &&
      entry.name !== 'jest.config.lua'
    ) {
      files.push(path.relative(baseDir, fullPath));
    }
  }
  return files;
}

async function existsAsync(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}
