import * as fsPromises from 'fs/promises';
import * as path from 'path';

async function pathExistsAsync(filePath: string): Promise<boolean> {
  try {
    await fsPromises.access(filePath);
    return true;
  } catch {
    return false;
  }
}

/**
 * Walks up from `fromDirectory` looking for a `.git` entry and returns the
 * directory that contains it. Returns `undefined` if no git root is found.
 */
export async function findGitRepoRootAsync(
  fromDirectory: string
): Promise<string | undefined> {
  let current = path.resolve(fromDirectory);
  while (true) {
    if (await pathExistsAsync(path.join(current, '.git'))) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) {
      return undefined;
    }
    current = parent;
  }
}
