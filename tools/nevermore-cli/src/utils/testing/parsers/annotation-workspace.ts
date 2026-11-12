import * as fs from 'fs/promises';
import * as path from 'path';
import {
  filterByTargetAsync,
  listWorkspacePackagesAsync,
} from '../../batch/changed-packages-utils.js';
import {
  type TestRojoProject,
  findTestProjectSlug,
} from '../runner/test-project-slug.js';

export interface AnnotationWorkspacePackage {
  /** Repo-relative POSIX directory, e.g. `src/player-mock` */
  dir: string;
  /** Rojo project name, which the sourcemap uses */
  projectName?: string;
  /** Instance names the package gets in its test places */
  testSlugs: string[];
}

export interface AnnotationWorkspace {
  packagesByName: Map<string, AnnotationWorkspacePackage>;
}

/**
 * Index the pnpm workspace for mapping test output back to files. Returns
 * `undefined` when the workspace can't be listed.
 */
export async function tryLoadAnnotationWorkspaceAsync(
  repoRoot: string
): Promise<AnnotationWorkspace | undefined> {
  let packages;
  try {
    packages = await listWorkspacePackagesAsync(repoRoot);
  } catch {
    return undefined;
  }

  const packagesByName = new Map<string, AnnotationWorkspacePackage>();
  await Promise.all(
    packages.map(async (pkg) => {
      const project = await _tryReadJsonAsync<{ name?: string }>(
        path.join(pkg.path, 'default.project.json')
      );
      packagesByName.set(pkg.name, {
        dir: path.relative(repoRoot, pkg.path).replace(/\\/g, '/'),
        projectName: project?.name,
        testSlugs: [],
      });
    })
  );

  for (const testPackage of await filterByTargetAsync(packages, 'test')) {
    const entry = packagesByName.get(testPackage.name);
    if (!entry) continue;
    for (const target of testPackage.activeTargets) {
      const project = await _tryReadJsonAsync<TestRojoProject>(
        path.resolve(testPackage.path, target.project)
      );
      const slug = project && findTestProjectSlug(project);
      if (slug && !entry.testSlugs.includes(slug)) entry.testSlugs.push(slug);
    }
  }

  return { packagesByName };
}

async function _tryReadJsonAsync<T>(filePath: string): Promise<T | undefined> {
  try {
    return JSON.parse(await fs.readFile(filePath, 'utf-8')) as T;
  } catch {
    return undefined;
  }
}
