/**
 * Shared helpers for parsing lerna-prefixed linter output.
 *
 * When linters run via `npx lerna exec --parallel`, each output line
 * may be prefixed with `@scope/packageName: `. File paths in the output
 * are relative to the package directory, not the repo root.
 */

/**
 * Optional lerna prefix pattern: `@scope/pkg: `
 * Captures the package name (without scope) in group 1.
 * Use as a prefix in other patterns: `(?:${LERNA_PREFIX_PATTERN})?`
 */
export const LERNA_PREFIX_PATTERN = String.raw`@[\w-]+\/([\w-]+):\s+`;

/**
 * Same pattern but without the capture group (for location lines
 * where the package name is already known from the header).
 */
export const LERNA_PREFIX_PATTERN_NC = String.raw`@[\w-]+\/[\w-]+:\s+`;

/**
 * Resolve a package-relative file path to a repo-root-relative path.
 *
 * When a lerna prefix is present, the linter runs inside `src/{pkg}/`
 * so its output paths are relative to that directory. This prepends
 * the package directory to produce a repo-root-relative path.
 */
export function resolvePackagePath(
  packageName: string | undefined,
  filePath: string
): string {
  if (!packageName) return filePath;
  return `src/${packageName}/${filePath}`;
}
