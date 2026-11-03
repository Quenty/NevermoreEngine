/**
 * The plugin reports a hash of the template it was built from as its
 * `pluginVersion`, so the CLI can tell when the installed plugin is stale.
 */

import { createHash } from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';
import { resolveTemplatePath } from '@quenty/nevermore-template-helpers';

const templateDir = resolveTemplatePath(
  import.meta.url,
  'studio-bridge-plugin'
);

let cachedVersion: Promise<string> | undefined;

export function getPluginBuildVersionAsync(): Promise<string> {
  cachedVersion ??= hashTemplateDirAsync(templateDir);
  return cachedVersion;
}

export async function hashTemplateDirAsync(dir: string): Promise<string> {
  const files = await listTemplateFilesAsync(dir, dir);
  files.sort();

  const hash = createHash('sha256');
  for (const relativePath of files) {
    const contents = await fs.readFile(path.join(dir, relativePath), 'utf-8');
    hash.update(relativePath.replace(/\\/g, '/'));
    hash.update('\0');
    hash.update(contents.replace(/\r\n/g, '\n'));
    hash.update('\0');
  }
  return hash.digest('hex').slice(0, 12);
}

async function listTemplateFilesAsync(
  baseDir: string,
  currentDir: string
): Promise<string[]> {
  const entries = await fs.readdir(currentDir, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const fullPath = path.join(currentDir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await listTemplateFilesAsync(baseDir, fullPath)));
    } else if (!entry.name.endsWith('.spec.lua')) {
      files.push(path.relative(baseDir, fullPath));
    }
  }
  return files;
}
