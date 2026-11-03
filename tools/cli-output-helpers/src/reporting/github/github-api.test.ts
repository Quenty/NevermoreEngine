import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { resolveGitHubContext } from './github-api.js';

describe('resolveGitHubContext', () => {
  beforeEach(() => {
    vi.stubEnv('GITHUB_TOKEN', 'token');
    vi.stubEnv('GITHUB_REPOSITORY', 'Quenty/NevermoreEngine');
    vi.stubEnv('GITHUB_REF_NAME', 'main');
    vi.stubEnv('GITHUB_EVENT_PATH', '');
    vi.stubEnv('NEVERMORE_CI_PR_NUMBER', '');
  });

  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it('finds no PR on a default-branch run', () => {
    expect(resolveGitHubContext()).toBeUndefined();
  });

  it('reads the PR from a merge ref', () => {
    vi.stubEnv('GITHUB_REF_NAME', '852/merge');

    expect(resolveGitHubContext()?.prNumber).toBe(852);
  });

  it('takes the PR number override over the ref', () => {
    vi.stubEnv('GITHUB_REF_NAME', '852/merge');
    vi.stubEnv('NEVERMORE_CI_PR_NUMBER', '846');

    expect(resolveGitHubContext()?.prNumber).toBe(846);
  });

  it('ignores a PR number override that is not a number', () => {
    vi.stubEnv('NEVERMORE_CI_PR_NUMBER', '846; rm -rf /');

    expect(resolveGitHubContext()).toBeUndefined();
  });
});
