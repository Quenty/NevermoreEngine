import { describe, it, expect, vi, beforeEach } from 'vitest';
import { parseJestLuaOutput } from './jest-lua-parser.js';
import { SourcemapResolver } from '../../sourcemap/index.js';
import type { SourcemapNode } from '../../sourcemap/index.js';

// Mock fs.readFileSync for _findTestLineInFile
vi.mock('fs', () => ({
  readFileSync: vi.fn(() => {
    throw new Error('ENOENT');
  }),
}));

describe('parseJestLuaOutput', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('parses a single assertion failure with at location', () => {
    const input = [
      '  ● ObservableList > add and remove > should track count',
      '',
      '    expect(received).toEqual(expected)',
      '',
      '    Expected: 3',
      '    Received: 2',
      '',
      '      at ServerScriptService.observablecollection.Shared.ObservableList.spec:45',
    ].join('\n');

    const result = parseJestLuaOutput(input, {
      packageName: 'observablecollection',
    });

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      file: 'src/observablecollection/src/Shared/ObservableList.spec.lua',
      line: 45,
      severity: 'error',
      title: 'ObservableList > add and remove > should track count',
      message: expect.stringContaining('expect(received).toEqual(expected)'),
      source: 'jest-lua',
    });
    expect(result[0].message).toContain('Expected: 3');
    expect(result[0].message).toContain('Received: 2');
  });

  it('parses multiple failures in one log', () => {
    const input = [
      '  ● Suite > test one',
      '',
      '    Expected: 1',
      '    Received: 2',
      '',
      '      at ServerScriptService.mypkg.Shared.Foo.spec:10',
      '',
      '  ● Suite > test two',
      '',
      '    Expected: true',
      '    Received: false',
      '',
      '      at ServerScriptService.mypkg.Shared.Bar.spec:20',
    ].join('\n');

    const result = parseJestLuaOutput(input, { packageName: 'mypkg' });

    expect(result).toHaveLength(2);
    expect(result[0].title).toBe('Suite > test one');
    expect(result[0].line).toBe(10);
    expect(result[1].title).toBe('Suite > test two');
    expect(result[1].line).toBe(20);
  });

  it('parses nested 3+ level test hierarchy', () => {
    const input = [
      '  ● Level1 > Level2 > Level3 > Level4 > deep test',
      '',
      '    failure message',
      '',
      '      at ServerScriptService.pkg.Shared.Deep.spec:99',
    ].join('\n');

    const result = parseJestLuaOutput(input, { packageName: 'pkg' });

    expect(result).toHaveLength(1);
    expect(result[0].title).toBe(
      'Level1 > Level2 > Level3 > Level4 > deep test'
    );
  });

  it('falls back to line 1 when no at location and file not found', () => {
    const input = [
      '  ● Suite > test without location',
      '',
      '    some error happened',
      '',
      'Test Suites: 1 failed, 1 total',
    ].join('\n');

    const result = parseJestLuaOutput(input, { packageName: 'mypkg' });

    expect(result).toHaveLength(1);
    expect(result[0].line).toBe(1);
    expect(result[0].file).toBe('src/mypkg/src');
  });

  it('searches spec file for it() call when at location has no line number', async () => {
    const { readFileSync } = await import('fs');
    const mockedReadFileSync = vi.mocked(readFileSync);
    mockedReadFileSync.mockReturnValue(
      [
        'local require = require(script.Parent.loader).load(script)',
        '',
        'describe("Suite", function()',
        '  it("my test name", function()',
        '    -- test body',
        '  end)',
        'end)',
      ].join('\n')
    );

    const input = [
      '  ● Suite > my test name',
      '',
      '    assertion failed',
      '',
      '      at ServerScriptService.mypkg.Shared.Foo.spec',
    ].join('\n');

    const result = parseJestLuaOutput(input, { packageName: 'mypkg' });

    expect(result).toHaveLength(1);
    expect(result[0].file).toBe('src/mypkg/src/Shared/Foo.spec.lua');
    expect(result[0].line).toBe(4);
  });

  it('parses a runtime error with Stack Begin/Stack End', () => {
    const input = [
      'Error: attempt to index nil with "Connect"',
      'Stack Begin',
      "Script 'ServerScriptService.maid.Shared.Maid.spec', Line 23",
      'Stack End',
    ].join('\n');

    const result = parseJestLuaOutput(input, { packageName: 'maid' });

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      file: 'src/maid/src/Shared/Maid.spec.lua',
      line: 23,
      severity: 'error',
      title: 'Runtime error',
      message: 'Error: attempt to index nil with "Connect"',
      source: 'jest-lua',
    });
  });

  it('parses mixed Jest failures and runtime errors', () => {
    const input = [
      '  ● Suite > assertion test',
      '',
      '    Expected: 1',
      '    Received: 2',
      '',
      '      at ServerScriptService.pkg.Shared.Foo.spec:10',
      '',
      'Error: attempt to call nil value',
      'Stack Begin',
      "Script 'ServerScriptService.pkg.Shared.Bar.spec', Line 5",
      'Stack End',
    ].join('\n');

    const result = parseJestLuaOutput(input, { packageName: 'pkg' });

    expect(result).toHaveLength(2);
    expect(result[0].title).toBe('Suite > assertion test');
    expect(result[0].source).toBe('jest-lua');
    expect(result[1].title).toBe('Runtime error');
    expect(result[1].line).toBe(5);
  });

  it('returns empty array for all-passing output', () => {
    const input = [
      'PASS  ServerScriptService.maid',
      '  Maid',
      '    ✓ should create (5 ms)',
      '    ✓ should destroy (2 ms)',
      '',
      'Test Suites: 1 passed, 1 total',
      'Tests:       2 passed, 2 total',
    ].join('\n');

    const result = parseJestLuaOutput(input, { packageName: 'maid' });

    expect(result).toEqual([]);
  });

  it('strips ANSI escape codes cleanly', () => {
    const input = [
      '  \x1b[31m●\x1b[39m \x1b[1mSuite > test\x1b[22m',
      '',
      '    \x1b[31mExpected: 1\x1b[39m',
      '    \x1b[32mReceived: 2\x1b[39m',
      '',
      '      at ServerScriptService.pkg.Shared.Foo.spec:10',
    ].join('\n');

    const result = parseJestLuaOutput(input, { packageName: 'pkg' });

    expect(result).toHaveLength(1);
    expect(result[0].title).toBe('Suite > test');
    expect(result[0].line).toBe(10);
    // Ensure no ANSI codes leaked into the message
    expect(result[0].message).not.toMatch(/\x1b/);
  });

  it('handles truncated/incomplete output without crashing', () => {
    const input = [
      '  ● Suite > incomplete test',
      '',
      '    partial error message',
      // No at-line, no Stack Begin, just ends
    ].join('\n');

    const result = parseJestLuaOutput(input, { packageName: 'pkg' });

    // Should still emit a diagnostic with fallback location
    expect(result).toHaveLength(1);
    expect(result[0].title).toBe('Suite > incomplete test');
    expect(result[0].line).toBe(1);
  });

  it('handles empty input', () => {
    const result = parseJestLuaOutput('', { packageName: 'pkg' });
    expect(result).toEqual([]);
  });

  it('uses last stack frame for location in multi-frame stack', () => {
    const input = [
      'Error: bad argument',
      'Stack Begin',
      "Script 'ServerScriptService.pkg.Shared.Inner', Line 10",
      "Script 'ServerScriptService.pkg.Shared.Outer.spec', Line 30",
      'Stack End',
    ].join('\n');

    const result = parseJestLuaOutput(input, { packageName: 'pkg' });

    expect(result).toHaveLength(1);
    expect(result[0].file).toBe('src/pkg/src/Shared/Outer.spec.lua');
    expect(result[0].line).toBe(30);
  });

  describe('with sourcemap resolver', () => {
    const repoRoot = '/repo';

    const sourcemap: SourcemapNode = {
      name: 'Nevermore',
      className: 'DataModel',
      children: [
        {
          name: 'mypkg',
          className: 'Folder',
          filePaths: [`${repoRoot}/src/mypkg/default.project.json`],
          children: [
            {
              name: 'Shared',
              className: 'Folder',
              children: [
                {
                  name: 'Foo',
                  className: 'ModuleScript',
                  filePaths: [`${repoRoot}/src/mypkg/src/Shared/Foo.lua`],
                  children: [
                    {
                      name: 'Foo.spec',
                      className: 'ModuleScript',
                      filePaths: [
                        `${repoRoot}/src/mypkg/src/Shared/Foo.spec.lua`,
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    };

    const resolver = SourcemapResolver.fromSourcemap(sourcemap, repoRoot);

    it('uses sourcemap resolver for assertion failure paths', () => {
      const input = [
        '  ● Suite > test one',
        '',
        '    Expected: 1',
        '    Received: 2',
        '',
        '      at ServerScriptService.mypkg.Shared.Foo.Foo.spec:10',
      ].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: 'mypkg',
        sourcemapResolver: resolver,
      });

      expect(result).toHaveLength(1);
      expect(result[0].file).toBe('src/mypkg/src/Shared/Foo.spec.lua');
      expect(result[0].line).toBe(10);
    });

    it('uses sourcemap resolver for runtime error paths', () => {
      const input = [
        'Error: attempt to index nil',
        'Stack Begin',
        "Script 'ServerScriptService.mypkg.Shared.Foo.Foo.spec', Line 5",
        'Stack End',
      ].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: 'mypkg',
        sourcemapResolver: resolver,
      });

      expect(result).toHaveLength(1);
      expect(result[0].file).toBe('src/mypkg/src/Shared/Foo.spec.lua');
      expect(result[0].line).toBe(5);
    });

    it('falls back to heuristic when sourcemap has no mapping', () => {
      const input = [
        '  ● Suite > test one',
        '',
        '    Expected: 1',
        '    Received: 2',
        '',
        '      at ServerScriptService.unknown.Shared.Bar.spec:10',
      ].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: 'unknown',
        sourcemapResolver: resolver,
      });

      expect(result).toHaveLength(1);
      // Falls back to heuristic
      expect(result[0].file).toBe('src/unknown/src/Shared/Bar.spec.lua');
    });
  });
});
