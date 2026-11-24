import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import {
  findPublishWorkflowsAsync,
  getGithubTrustStatus,
  isNpmTrustSupported,
  isPublishWorkflow,
  isTransientNpmFailure,
  parseGithubRepository,
  parseTrustListJson,
  selectPackages,
  withRetriesAsync,
} from './npm-trust-utils.js';

const target = { repository: 'Quenty/NevermoreEngine', file: 'build.yml' };

describe('parseTrustListJson', () => {
  it('returns nothing for empty output', () => {
    expect(parseTrustListJson('')).toEqual([]);
    expect(parseTrustListJson('\n')).toEqual([]);
  });

  it('parses back-to-back objects', () => {
    const stdout = [
      JSON.stringify(
        { id: 'a', type: 'github', file: 'build.yml', repository: 'x/y' },
        null,
        2
      ),
      JSON.stringify(
        { id: 'b', type: 'gitlab', file: '.gitlab-ci.yml', note: '{"}' },
        null,
        2
      ),
    ].join('\n');

    const configs = parseTrustListJson(stdout);
    expect(configs.map((c) => c.id)).toEqual(['a', 'b']);
  });
});

describe('getGithubTrustStatus', () => {
  it('is missing when there are no configs', () => {
    expect(getGithubTrustStatus([], target)).toBe('missing');
  });

  it('is trusted when repository and workflow match', () => {
    expect(
      getGithubTrustStatus(
        [
          {
            type: 'github',
            repository: 'quenty/nevermoreengine',
            file: 'build.yml',
            permissions: ['createPackage'],
          },
        ],
        target
      )
    ).toBe('trusted');
  });

  it('is mismatched for another workflow or a stage-only config', () => {
    expect(
      getGithubTrustStatus(
        [{ type: 'github', repository: target.repository, file: 'other.yml' }],
        target
      )
    ).toBe('mismatched');
    expect(
      getGithubTrustStatus(
        [
          {
            type: 'github',
            repository: target.repository,
            file: 'build.yml',
            permissions: ['createStagedPackage'],
          },
        ],
        target
      )
    ).toBe('mismatched');
  });
});

describe('selectPackages', () => {
  const packages = [
    { name: '@quenty/maid', path: '/repo/src/maid' },
    { name: '@quenty/rx', path: '/repo/src/rx' },
  ];

  it('returns everything with no selectors', () => {
    expect(selectPackages(packages, [])).toBe(packages);
  });

  it('matches by full name or directory name', () => {
    expect(
      selectPackages(packages, ['maid', '@quenty/rx']).map((p) => p.name)
    ).toEqual(['@quenty/maid', '@quenty/rx']);
  });

  it('throws on unknown selectors', () => {
    expect(() => selectPackages(packages, ['nope'])).toThrow(/nope/);
  });
});

describe('parseGithubRepository', () => {
  it.each([
    ['https://github.com/Quenty/NevermoreEngine.git', 'Quenty/NevermoreEngine'],
    [
      'git+https://github.com/Quenty/NevermoreEngine.git',
      'Quenty/NevermoreEngine',
    ],
    ['git://github.com/owner/repo', 'owner/repo'],
    ['git+ssh://git@github.com/owner/repo.git', 'owner/repo'],
    ['git@github.com:owner/repo.git', 'owner/repo'],
    ['github:owner/repo', 'owner/repo'],
    ['owner/repo', 'owner/repo'],
    ['https://github.com/owner/repo/', 'owner/repo'],
  ])('parses %s', (input, expected) => {
    expect(parseGithubRepository(input)).toBe(expected);
    expect(parseGithubRepository({ url: input })).toBe(expected);
  });

  it('rejects other hosts and empty values', () => {
    expect(parseGithubRepository('https://gitlab.com/owner/repo')).toBe(
      undefined
    );
    expect(parseGithubRepository(undefined)).toBe(undefined);
    expect(parseGithubRepository({})).toBe(undefined);
  });
});

describe('isPublishWorkflow', () => {
  it('needs both an OIDC token and a publish step', () => {
    const withToken = 'permissions:\n  id-token: write\n';
    expect(isPublishWorkflow(`${withToken}    run: npx auto shipit\n`)).toBe(
      true
    );
    expect(isPublishWorkflow(`${withToken}    run: npm publish\n`)).toBe(true);
    expect(isPublishWorkflow(`${withToken}    run: npm test\n`)).toBe(false);
    expect(isPublishWorkflow('    run: npm publish\n')).toBe(false);
  });
});

describe('findPublishWorkflowsAsync', () => {
  let root: string;

  beforeEach(async () => {
    root = await fs.mkdtemp(path.join(os.tmpdir(), 'nevermore-wf-'));
    await fs.mkdir(path.join(root, '.github', 'workflows'), {
      recursive: true,
    });
  });

  afterEach(async () => {
    await fs.rm(root, { recursive: true, force: true });
  });

  it('finds only publishing workflows', async () => {
    const dir = path.join(root, '.github', 'workflows');
    await fs.writeFile(
      path.join(dir, 'release.yml'),
      'permissions:\n  id-token: write\njobs:\n  x:\n    steps:\n      - run: pnpm publish -r\n'
    );
    await fs.writeFile(path.join(dir, 'test.yaml'), 'jobs: {}\n');
    await fs.writeFile(
      path.join(dir, 'notes.md'),
      'id-token: write npm publish'
    );

    expect(await findPublishWorkflowsAsync(root)).toEqual(['release.yml']);
  });

  it('returns nothing without a workflows directory', async () => {
    expect(await findPublishWorkflowsAsync(path.join(root, 'nope'))).toEqual(
      []
    );
  });
});

describe('isTransientNpmFailure', () => {
  it('recognises server errors and network failures', () => {
    expect(isTransientNpmFailure('npm error code E503')).toBe(true);
    expect(isTransientNpmFailure('npm error 500 Internal Server Error')).toBe(
      true
    );
    expect(isTransientNpmFailure('npm error code E429')).toBe(true);
    expect(isTransientNpmFailure('npm error code ECONNRESET')).toBe(true);
  });

  it('leaves real failures alone', () => {
    expect(isTransientNpmFailure('npm error code E404')).toBe(false);
    expect(isTransientNpmFailure('npm error code EOTP')).toBe(false);
    expect(isTransientNpmFailure('npm error code E403')).toBe(false);
  });
});

describe('withRetriesAsync', () => {
  it('retries retryable failures until success', async () => {
    let calls = 0;
    const result = await withRetriesAsync(
      async () => {
        calls++;
        if (calls < 3) {
          throw new Error('flaky');
        }
        return 'ok';
      },
      { isRetryable: () => true, baseDelayMs: 0 }
    );
    expect(result).toBe('ok');
    expect(calls).toBe(3);
  });

  it('stops on a non-retryable failure', async () => {
    let calls = 0;
    await expect(
      withRetriesAsync(
        async () => {
          calls++;
          throw new Error('fatal');
        },
        { isRetryable: () => false, baseDelayMs: 0 }
      )
    ).rejects.toThrow('fatal');
    expect(calls).toBe(1);
  });

  it('gives up after the last attempt', async () => {
    let calls = 0;
    await expect(
      withRetriesAsync(
        async () => {
          calls++;
          throw new Error('down');
        },
        { isRetryable: () => true, attempts: 2, baseDelayMs: 0 }
      )
    ).rejects.toThrow('down');
    expect(calls).toBe(2);
  });
});

describe('isNpmTrustSupported', () => {
  it('requires npm 11.15+', () => {
    expect(isNpmTrustSupported('11.14.9')).toBe(false);
    expect(isNpmTrustSupported('11.15.0')).toBe(true);
    expect(isNpmTrustSupported('12.2.2\n')).toBe(true);
    expect(isNpmTrustSupported('garbage')).toBe(false);
  });
});
