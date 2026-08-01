import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  describeMissingWatchToken,
  parseGithubRepository,
  tryResolveGithubDispatchContext,
} from './github-context.js';

// ESM exports cannot be spied on, so the module is mocked outright.
const execSyncMock = vi.hoisted(() => vi.fn());
vi.mock('child_process', () => ({ execSync: execSyncMock }));

afterEach(() => {
  execSyncMock.mockReset();
  vi.unstubAllEnvs();
});

/** Answers the subprocesses github-context shells out to. */
function stubCommands(answers: Record<string, string | Error>) {
  execSyncMock.mockImplementation((cmd: string) => {
    for (const [prefix, answer] of Object.entries(answers)) {
      if (cmd.startsWith(prefix)) {
        if (answer instanceof Error) {
          throw answer;
        }
        return answer;
      }
    }
    throw new Error(`unstubbed command: ${cmd}`);
  });
}

describe('tryResolveGithubDispatchContext token', () => {
  const REPO_AND_REF = {
    'git remote get-url origin': 'git@github.com:Quenty/Nevermore.git',
    'git rev-parse': 'main',
  };

  // Cleared so these exercise the git fallback rather than whatever the host
  // happens to export. Actions sets both, and on a pull request GITHUB_REF_NAME
  // is a merge ref — which resolution rightly refuses, so without this the
  // whole describe passes locally and fails only in CI.
  beforeEach(() => {
    vi.stubEnv('GITHUB_REPOSITORY', '');
    vi.stubEnv('GITHUB_REF_NAME', '');
  });

  // Registering ships the token to the watch service, so it has to be one the
  // user handed over. Nearly every dev machine has a logged-in `gh`, so reading
  // it by default would turn a local watch into a silent credential send.
  it('does not consult gh unless asked', () => {
    vi.stubEnv('NEVERMORE_WATCH_TOKEN', '');
    vi.stubEnv('GITHUB_TOKEN', '');
    stubCommands({
      ...REPO_AND_REF,
      'gh auth token': new Error('gh must not be consulted'),
    });

    const result = tryResolveGithubDispatchContext();
    expect(result.success && result.context.token).toBeUndefined();
  });

  it('reads the GitHub CLI token when explicitly asked', () => {
    vi.stubEnv('NEVERMORE_WATCH_TOKEN', '');
    vi.stubEnv('GITHUB_TOKEN', '');
    stubCommands({ ...REPO_AND_REF, 'gh auth token': 'gho_from_cli' });

    const result = tryResolveGithubDispatchContext({ useGhAuth: true });
    expect(result.success && result.context.token).toBe('gho_from_cli');
  });

  // CI sets the env var, and must never pay for the subprocess.
  it('prefers the env var and does not shell out to gh', () => {
    vi.stubEnv('NEVERMORE_WATCH_TOKEN', 'from-env');
    stubCommands({
      ...REPO_AND_REF,
      'gh auth token': new Error('gh should not be consulted'),
    });

    const result = tryResolveGithubDispatchContext({ useGhAuth: true });
    expect(result.success && result.context.token).toBe('from-env');
  });

  it('reports no token when gh is missing or logged out', () => {
    vi.stubEnv('NEVERMORE_WATCH_TOKEN', '');
    vi.stubEnv('GITHUB_TOKEN', '');
    stubCommands({
      ...REPO_AND_REF,
      'gh auth token': new Error('gh: command not found'),
    });

    const result = tryResolveGithubDispatchContext({ useGhAuth: true });
    expect(result.success && result.context.token).toBeUndefined();
  });

  // A logged-out `gh` exits non-zero, but a notice printed to stdout would sail
  // through as a "token" and fail much later as a confusing 401.
  it('refuses output that cannot be a token', () => {
    vi.stubEnv('NEVERMORE_WATCH_TOKEN', '');
    vi.stubEnv('GITHUB_TOKEN', '');
    stubCommands({
      ...REPO_AND_REF,
      'gh auth token': 'You are not logged in. Run gh auth login',
    });

    const result = tryResolveGithubDispatchContext({ useGhAuth: true });
    expect(result.success && result.context.token).toBeUndefined();
  });

  it('names both ways of supplying a token when none is found', () => {
    expect(describeMissingWatchToken()).toMatch(/NEVERMORE_WATCH_TOKEN/);
    expect(describeMissingWatchToken()).toMatch(/--watch-use-gh-auth/);
  });
});

describe('parseGithubRepository', () => {
  it('parses an https remote', () => {
    expect(
      parseGithubRepository('https://github.com/Quenty/Nevermore.git')
    ).toBe('Quenty/Nevermore');
  });

  it('parses an https remote without the .git suffix', () => {
    expect(parseGithubRepository('https://github.com/Quenty/Nevermore')).toBe(
      'Quenty/Nevermore'
    );
  });

  it('parses an scp-style ssh remote', () => {
    expect(parseGithubRepository('git@github.com:Quenty/Nevermore.git')).toBe(
      'Quenty/Nevermore'
    );
  });

  it('parses an ssh:// remote', () => {
    expect(
      parseGithubRepository('ssh://git@github.com/Quenty/Nevermore.git')
    ).toBe('Quenty/Nevermore');
  });

  it('parses a remote with credentials embedded', () => {
    expect(
      parseGithubRepository(
        'https://user:token@github.com/Quenty/Nevermore.git'
      )
    ).toBe('Quenty/Nevermore');
  });

  it('tolerates surrounding whitespace and a trailing slash', () => {
    expect(
      parseGithubRepository('  https://github.com/Quenty/Nevermore/  ')
    ).toBe('Quenty/Nevermore');
  });

  it('ignores a non-GitHub host', () => {
    expect(
      parseGithubRepository('https://gitlab.com/Quenty/Nevermore.git')
    ).toBeUndefined();
  });

  it('ignores a local path remote', () => {
    expect(parseGithubRepository('/srv/git/Nevermore.git')).toBeUndefined();
  });
});
