import { execSync } from 'child_process';

/**
 * Env var holding the token the watch service dispatches with. Checked before
 * `GITHUB_TOKEN` so a long-lived registration token can be kept separate from
 * the short-lived one a workflow run is handed — an Actions `GITHUB_TOKEN`
 * expires with its job, which would outlive nothing.
 */
const WATCH_TOKEN_ENV = 'NEVERMORE_WATCH_TOKEN';

/** Everything the watch service needs to dispatch a workflow back at us. */
export interface GithubDispatchContext {
  /** `owner/repo`. */
  repository: string;
  /** Git ref the dispatched workflow should run on. */
  ref: string;
  /** Token the service dispatches with; absent when none was provided. */
  token?: string;
}

export interface GithubContextOptions {
  /**
   * Read the token from the GitHub CLI when no environment variable supplies
   * one.
   *
   * Off unless asked for, and that is the whole point. Registering sends a PAT
   * to the watch service and creates a monitor against the repository, so the
   * credential has to be one the user handed over — an env var is handing it
   * over, reading whatever `gh` happens to be holding is not. Nearly every
   * developer machine has a logged-in `gh`, so defaulting this on would turn a
   * command that used to watch locally into one that quietly ships a token.
   */
  useGhAuth?: boolean;
}

export type GithubContextResult =
  | { success: true; context: GithubDispatchContext }
  | {
      success: false;
      reason: 'no_repository' | 'no_ref' | 'undispatchable_ref';
    };

/**
 * A `pull_request` run exposes `GITHUB_REF_NAME` as `42/merge` — a synthetic
 * merge ref that exists only for that check run. It is not a branch, so
 * `workflow_dispatch` cannot run on it, and it disappears when the PR closes.
 */
const MERGE_REF_PATTERN = /^\d+\/(merge|head)$/;

/**
 * Read an env var, treating empty as absent.
 *
 * CI sets a variable to the empty string when the secret behind it is missing
 * (`FOO: ${{ secrets.ABSENT }}`), which `??` would accept as a real value —
 * so the documented fallback to the next source would never fire.
 */
function _env(name: string): string | undefined {
  const value = process.env[name];
  return value == null || value === '' ? undefined : value;
}

/**
 * Work out which repo and ref a watch should dispatch.
 *
 * Prefers the Actions environment, which is authoritative when we are already
 * running inside the workflow being registered, and falls back to the git
 * remote so `--watch <url>` also works from a developer's machine. Best-effort:
 * outside a git repo with no Actions env there is simply nothing to dispatch.
 */
export function tryResolveGithubDispatchContext(
  options: GithubContextOptions = {}
): GithubContextResult {
  const repository = _env('GITHUB_REPOSITORY') ?? _repositoryFromRemote();
  if (!repository) {
    return { success: false, reason: 'no_repository' };
  }

  const ref =
    _env('GITHUB_REF_NAME') ?? _git(['rev-parse', '--abbrev-ref', 'HEAD']);
  // A detached HEAD gives "HEAD", which is not a ref a dispatch can run on.
  if (!ref || ref === 'HEAD') {
    return { success: false, reason: 'no_ref' };
  }
  if (MERGE_REF_PATTERN.test(ref)) {
    return { success: false, reason: 'undispatchable_ref' };
  }

  const token =
    _env(WATCH_TOKEN_ENV) ??
    _env('GITHUB_TOKEN') ??
    (options.useGhAuth ? _githubCliToken() : undefined);

  return { success: true, context: { repository, ref, token } };
}

/** Human-facing explanation for a failed context resolution. */
export function describeGithubContextFailure(
  reason: 'no_repository' | 'no_ref' | 'undispatchable_ref'
): string {
  if (reason === 'no_repository') {
    return (
      'Could not determine the GitHub repository to dispatch. Set ' +
      'GITHUB_REPOSITORY (owner/repo), or run from a clone with a GitHub ' +
      '"origin" remote.'
    );
  }
  if (reason === 'undispatchable_ref') {
    return (
      'Refusing to register a watch from a pull request merge ref. That ref ' +
      'exists only for this check run, so a dispatch against it would fail ' +
      'and it disappears when the PR closes. Register from a branch instead ' +
      '(e.g. on push to main).'
    );
  }
  return (
    'Could not determine the git ref to dispatch on. Set GITHUB_REF_NAME, or ' +
    'check out a branch (a detached HEAD has no ref to run a workflow from).'
  );
}

/** Hint printed when a cloud registration has no credential to hand over. */
export function describeMissingWatchToken(): string {
  return [
    'No GitHub token found. The watch service identifies you by repository, ' +
      'so registering needs a token with "actions: write" on it. Either:',
    `  - Set: ${WATCH_TOKEN_ENV} (or GITHUB_TOKEN)`,
    '  - Pass: --watch-use-gh-auth, to use the token `gh` already holds',
  ].join('\n');
}

/**
 * Pull `owner/repo` out of a git remote URL. Handles the HTTPS, SCP-style, and
 * ssh:// spellings git hands out, and ignores non-GitHub hosts — a watch
 * registration names a GitHub workflow, so anything else is not dispatchable.
 */
export function parseGithubRepository(remoteUrl: string): string | undefined {
  const trimmed = remoteUrl.trim();
  const match =
    /^(?:https?:\/\/|ssh:\/\/)?(?:[^@/]+@)?github\.com[:/]+([^/]+)\/(.+?)(?:\.git)?\/?$/i.exec(
      trimmed
    );
  if (!match) {
    return undefined;
  }
  return `${match[1]}/${match[2]}`;
}

function _repositoryFromRemote(): string | undefined {
  const remote = _git(['remote', 'get-url', 'origin']);
  return remote == null ? undefined : parseGithubRepository(remote);
}

/**
 * The token `gh` is already holding, if it is installed and logged in.
 *
 * Only ever called when the caller opted in. Not stored anywhere by us on
 * purpose: `gh` owns its own refresh, and copying a token into `~/.nevermore`
 * would leave a stale duplicate to expire behind everyone's back — the point is
 * reading the live one, for the one run that asked.
 */
function _githubCliToken(): string | undefined {
  const token = _run('gh', ['auth', 'token']);
  // A logged-out `gh` exits non-zero, but an odd version could print a notice
  // on stdout instead; a token is never whitespace.
  return token == null || /\s/.test(token) ? undefined : token;
}

function _git(args: string[]): string | undefined {
  return _run('git', args);
}

function _run(command: string, args: string[]): string | undefined {
  try {
    const output = execSync(`${command} ${args.join(' ')}`, {
      encoding: 'utf-8',
      timeout: 5000,
      stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();
    return output === '' ? undefined : output;
  } catch {
    // Not installed, not logged in, or not a repo — all "no answer here".
    return undefined;
  }
}
