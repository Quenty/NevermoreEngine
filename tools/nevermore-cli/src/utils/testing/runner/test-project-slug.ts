export interface TestRojoProject {
  tree?: { ServerScriptService?: Record<string, unknown> };
}

/**
 * The slug is the instance name a package gets in its test place: the first
 * non-`$`, non-`Script` key under ServerScriptService.
 */
export function findTestProjectSlug(
  project: TestRojoProject
): string | undefined {
  const serverScriptService = project.tree?.ServerScriptService;
  if (!serverScriptService) return undefined;

  return Object.keys(serverScriptService).find(
    (key) => !key.startsWith('$') && key !== 'Script'
  );
}
