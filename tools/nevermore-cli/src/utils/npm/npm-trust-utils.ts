import * as fs from 'fs/promises';
import * as path from 'path';
import type { PublishablePackage } from '../workspace-utils.js';

export const DEFAULT_NPM_REGISTRY = 'https://registry.npmjs.org/';

/** A trusted publisher configuration as `npm trust list --json` reports it. */
export interface NpmTrustConfig {
  id?: string;
  type?: string;
  file?: string;
  repository?: string;
  environment?: string;
  permissions?: string[];
}

export interface GithubTrustTarget {
  repository: string;
  file: string;
}

export type TrustStatus = 'trusted' | 'missing' | 'mismatched';

export interface RegistryCheckResult<T> {
  missing: T[];
  /** Packages whose lookup kept failing, with the last error */
  unknown: Array<{ pkg: T; error: string }>;
}

/**
 * Picks packages by full name (`@quenty/maid`) or directory name (`maid`).
 * Throws on any selector that matches nothing, since a typo would otherwise
 * silently configure nothing.
 */
export function selectPackages<T extends { name: string; path: string }>(
  packages: T[],
  selectors: string[]
): T[] {
  if (selectors.length === 0) {
    return packages;
  }

  const selected = new Map<string, T>();
  const unknown: string[] = [];
  for (const selector of selectors) {
    const match = packages.find(
      (pkg) => pkg.name === selector || path.basename(pkg.path) === selector
    );
    if (match) {
      selected.set(match.name, match);
    } else {
      unknown.push(selector);
    }
  }

  if (unknown.length > 0) {
    throw new Error(`Unknown or private package(s): ${unknown.join(', ')}`);
  }
  return [...selected.values()];
}

/**
 * `owner/repo` from a package.json `repository` field, when it points at
 * GitHub. Accepts the URL, `github:` and bare shorthand forms npm accepts.
 */
export function parseGithubRepository(
  repository: PublishablePackage['repository']
): string | undefined {
  const raw = typeof repository === 'string' ? repository : repository?.url;
  if (!raw) {
    return undefined;
  }

  const value = raw.trim();
  const patterns = [
    /^(?:git\+)?(?:https?|ssh|git):\/\/(?:[^@/]+@)?github\.com[/:]([^/]+)\/([^/#]+?)(?:\.git)?\/?(?:#.*)?$/i,
    /^git@github\.com:([^/]+)\/([^/#]+?)(?:\.git)?(?:#.*)?$/i,
    /^github:([^/]+)\/([^/#]+?)(?:#.*)?$/i,
    /^([\w.-]+)\/([\w.-]+?)(?:#.*)?$/,
  ];
  for (const pattern of patterns) {
    const match = pattern.exec(value);
    if (match) {
      return `${match[1]}/${match[2]}`;
    }
  }
  return undefined;
}

/**
 * Whether a workflow can publish through trusted publishing: it must request
 * an OIDC token, and something in it has to publish.
 */
export function isPublishWorkflow(contents: string): boolean {
  const requestsIdToken = /^\s*id-token:\s*write\b/m.test(contents);
  const publishes =
    /\b(npm|pnpm|yarn)\s+publish\b|\blerna\s+publish\b|\bauto\s+shipit\b|\bsemantic-release\b|\bchangeset\s+publish\b/.test(
      contents
    );
  return requestsIdToken && publishes;
}

/** Workflow file names under `.github/workflows` that look like publishers. */
export async function findPublishWorkflowsAsync(
  repoRoot: string
): Promise<string[]> {
  const directory = path.join(repoRoot, '.github', 'workflows');
  let files: string[];
  try {
    files = await fs.readdir(directory);
  } catch {
    return [];
  }

  const result: string[] = [];
  for (const file of files.sort()) {
    if (!/\.ya?ml$/.test(file)) {
      continue;
    }
    const contents = await fs.readFile(path.join(directory, file), 'utf-8');
    if (isPublishWorkflow(contents)) {
      result.push(file);
    }
  }
  return result;
}

/** Nearest ancestor with a `.git` entry. */
export async function findGitRootAsync(
  startDirectory: string
): Promise<string | undefined> {
  let directory = path.resolve(startDirectory);
  for (;;) {
    try {
      await fs.access(path.join(directory, '.git'));
      return directory;
    } catch {
      const parent = path.dirname(directory);
      if (parent === directory) {
        return undefined;
      }
      directory = parent;
    }
  }
}

/**
 * Runs `fn`, retrying failures `isRetryable` accepts with exponential
 * backoff. The last error is rethrown.
 */
export async function withRetriesAsync<T>(
  fn: () => Promise<T>,
  options: {
    isRetryable: (err: unknown) => boolean;
    attempts?: number;
    baseDelayMs?: number;
  }
): Promise<T> {
  const attempts = options.attempts ?? 3;
  const baseDelayMs = options.baseDelayMs ?? 1000;
  for (let attempt = 1; ; attempt++) {
    try {
      return await fn();
    } catch (err) {
      if (attempt >= attempts || !options.isRetryable(err)) {
        throw err;
      }
      await new Promise((resolve) =>
        setTimeout(resolve, baseDelayMs * 2 ** (attempt - 1))
      );
    }
  }
}

/** Transient failures worth retrying, from npm's output or a fetch error. */
export function isTransientNpmFailure(text: string): boolean {
  return /\bE(?:5\d\d|429)\b|\b(?:5\d\d|429) (?:Internal|Bad Gateway|Service|Gateway|Too Many)|ETIMEDOUT|ECONNRESET|ECONNREFUSED|EAI_AGAIN|socket hang up/i.test(
    text
  );
}

class RegistryResponseError extends Error {
  constructor(public readonly status: number, packageName: string) {
    super(`registry returned ${status} for ${packageName}`);
  }
}

/** Public registry lookup, no auth needed. Retries transient failures. */
export async function packageExistsOnRegistryAsync(
  name: string,
  registry: string
): Promise<boolean> {
  const escaped = name.replace('/', '%2f');
  const url = new URL(
    escaped,
    registry.endsWith('/') ? registry : `${registry}/`
  );

  return withRetriesAsync(
    async () => {
      const response = await fetch(url, {
        method: 'HEAD',
        headers: { Accept: 'application/vnd.npm.install-v1+json' },
      });
      if (response.status === 404) {
        return false;
      }
      if (!response.ok) {
        throw new RegistryResponseError(response.status, name);
      }
      return true;
    },
    {
      isRetryable: (err) =>
        !(err instanceof RegistryResponseError) ||
        err.status === 429 ||
        err.status >= 500,
    }
  );
}

/**
 * Looks every package up on its registry. A lookup that keeps failing lands
 * in `unknown` rather than aborting the rest.
 */
export async function checkRegistryAsync<
  T extends { name: string; registry?: string }
>(
  packages: T[],
  defaultRegistry: string,
  concurrency = 16
): Promise<RegistryCheckResult<T>> {
  const result: RegistryCheckResult<T> = { missing: [], unknown: [] };
  let next = 0;
  const workers = Array.from({ length: concurrency }, async () => {
    while (next < packages.length) {
      const pkg = packages[next++];
      try {
        const exists = await packageExistsOnRegistryAsync(
          pkg.name,
          pkg.registry ?? defaultRegistry
        );
        if (!exists) {
          result.missing.push(pkg);
        }
      } catch (err) {
        result.unknown.push({
          pkg,
          error: err instanceof Error ? err.message : String(err),
        });
      }
    }
  });
  await Promise.all(workers);
  result.missing.sort((a, b) => a.name.localeCompare(b.name));
  result.unknown.sort((a, b) => a.pkg.name.localeCompare(b.pkg.name));
  return result;
}

/**
 * `npm trust list --json` prints one pretty-printed object per configuration,
 * back to back rather than as an array, and prints nothing when there are none.
 */
export function parseTrustListJson(stdout: string): NpmTrustConfig[] {
  const configs: NpmTrustConfig[] = [];
  let depth = 0;
  let start = -1;
  let inString = false;
  let escaped = false;

  for (let i = 0; i < stdout.length; i++) {
    const char = stdout[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === '\\') {
        escaped = true;
      } else if (char === '"') {
        inString = false;
      }
      continue;
    }

    if (char === '"') {
      inString = true;
    } else if (char === '{') {
      if (depth === 0) {
        start = i;
      }
      depth++;
    } else if (char === '}') {
      depth--;
      if (depth === 0 && start !== -1) {
        configs.push(JSON.parse(stdout.slice(start, i + 1)));
        start = -1;
      }
    }
  }

  return configs;
}

export function getGithubTrustStatus(
  configs: NpmTrustConfig[],
  target: GithubTrustTarget
): TrustStatus {
  if (configs.length === 0) {
    return 'missing';
  }

  const matches = configs.some(
    (config) =>
      config.type === 'github' &&
      config.repository?.toLowerCase() === target.repository.toLowerCase() &&
      config.file === target.file &&
      (config.permissions === undefined ||
        config.permissions.includes('createPackage'))
  );
  return matches ? 'trusted' : 'mismatched';
}

/** `npm trust` needs npm 11.15 or newer. */
export function isNpmTrustSupported(npmVersion: string): boolean {
  const [major, minor] = npmVersion.trim().split('.').map(Number);
  if (Number.isNaN(major) || Number.isNaN(minor)) {
    return false;
  }
  return major > 11 || (major === 11 && minor >= 15);
}
