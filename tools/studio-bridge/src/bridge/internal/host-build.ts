import { createHash } from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { resolvePackagePath } from '@quenty/nevermore-template-helpers/resolve-template-path';

export interface HostBuild {
  version: string;
  build?: string;
  packagePath?: string;
}

let cached: Promise<HostBuild> | undefined;

export function getHostBuildAsync(): Promise<HostBuild> {
  cached ??= readHostBuildAsync();
  return cached;
}

async function readHostBuildAsync(): Promise<HostBuild> {
  const bridgeDir = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '..'
  );
  const serverDir = path.resolve(bridgeDir, '..', 'server');

  const result: HostBuild = { version: 'unknown' };
  try {
    const packageJsonPath = resolvePackagePath(import.meta.url, 'package.json');
    result.packagePath = path.dirname(packageJsonPath);
    const packageJson = JSON.parse(
      await fs.readFile(packageJsonPath, 'utf-8')
    ) as { version?: string };
    result.version = packageJson.version ?? 'unknown';
  } catch {}
  try {
    result.build = await hashCodeAsync([bridgeDir, serverDir]);
  } catch {}
  return result;
}

export async function hashCodeAsync(dirs: string[]): Promise<string> {
  const hash = createHash('sha256');
  for (const dir of dirs) {
    const files = (await listCodeFilesAsync(dir)).sort();
    for (const file of files) {
      hash.update(path.relative(dir, file).replace(/\\/g, '/'));
      hash.update('\0');
      hash.update(await fs.readFile(file));
      hash.update('\0');
    }
  }
  return hash.digest('hex').slice(0, 12);
}

async function listCodeFilesAsync(dir: string): Promise<string[]> {
  let entries;
  try {
    entries = await fs.readdir(dir, { withFileTypes: true });
  } catch {
    return [];
  }
  const files: string[] = [];
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== '__tests__' && entry.name !== 'node_modules') {
        files.push(...(await listCodeFilesAsync(fullPath)));
      }
    } else if (
      /\.(js|ts)$/.test(entry.name) &&
      !entry.name.endsWith('.d.ts') &&
      !entry.name.includes('.test.')
    ) {
      files.push(fullPath);
    }
  }
  return files;
}
