import { describe, it, expect } from 'vitest';
import { parseStyluaOutput } from './stylua-parser.js';

describe('parseStyluaOutput', () => {
  it('parses a single diff header', () => {
    const input = [
      'Diff in src/foo/Bar.lua:',
      '1        |-local x   =    1',
      '    1    |+local x = 1',
    ].join('\n');

    const result = parseStyluaOutput(input);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      file: 'src/foo/Bar.lua',
      line: 1,
      severity: 'warning',
      message: 'File is not formatted. Run stylua to fix.',
      title: 'stylua',
      source: 'stylua',
    });
  });

  it('parses multiple diff headers', () => {
    const input = [
      'Diff in src/a.lua:',
      '1        |-local x   =    1',
      '    1    |+local x = 1',
      'Diff in src/b.lua:',
      '1        |-local y   =    2',
      '    1    |+local y = 2',
    ].join('\n');

    const result = parseStyluaOutput(input);
    expect(result).toHaveLength(2);
    expect(result[0].file).toBe('src/a.lua');
    expect(result[1].file).toBe('src/b.lua');
  });

  it('returns empty array for clean output', () => {
    const result = parseStyluaOutput('');
    expect(result).toEqual([]);
  });

  it('handles paths with spaces', () => {
    const input = 'Diff in src/my folder/Bar.lua:';
    const result = parseStyluaOutput(input);

    expect(result).toHaveLength(1);
    expect(result[0].file).toBe('src/my folder/Bar.lua');
  });
});
