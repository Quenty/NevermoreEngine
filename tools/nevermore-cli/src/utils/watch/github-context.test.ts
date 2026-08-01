import { describe, it, expect } from 'vitest';
import { parseGithubRepository } from './github-context.js';

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
