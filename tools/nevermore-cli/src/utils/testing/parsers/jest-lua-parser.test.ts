import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { PathOrFileDescriptor } from 'fs';
import { fileURLToPath } from 'url';
import { parseJestLuaOutput } from './jest-lua-parser.js';
import { SourcemapResolver } from '../../sourcemap/index.js';
import type { SourcemapNode } from '../../sourcemap/index.js';

// readFileSync passes through so the workspace and existence checks run
// against the real repo layout; individual tests stub spec file contents.
vi.mock('fs', async (importOriginal) => {
  const actual = await importOriginal<typeof import('fs')>();
  return { ...actual, readFileSync: vi.fn(actual.readFileSync) };
});

const REPO_ROOT = fileURLToPath(new URL('../../../../../../', import.meta.url));

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
      packageName: '@quenty/observablecollection',
      repoRoot: REPO_ROOT,
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
      '      at ServerScriptService.observablecollection.Shared.ObservableList.spec:10',
      '',
      '  ● Suite > test two',
      '',
      '    Expected: true',
      '    Received: false',
      '',
      '      at ServerScriptService.observablecollection.Shared.ObservableMap.spec:20',
    ].join('\n');

    const result = parseJestLuaOutput(input, {
      packageName: '@quenty/observablecollection',
      repoRoot: REPO_ROOT,
    });

    expect(result).toHaveLength(2);
    expect(result[0].title).toBe('Suite > test one');
    expect(result[0].line).toBe(10);
    expect(result[1].title).toBe('Suite > test two');
    expect(result[1].file).toBe(
      'src/observablecollection/src/Shared/ObservableMap.spec.lua'
    );
    expect(result[1].line).toBe(20);
  });

  it('parses nested 3+ level test hierarchy', () => {
    const input = [
      '  ● Level1 > Level2 > Level3 > Level4 > deep test',
      '',
      '    failure message',
      '',
      '      at ServerScriptService.maid.Shared.MaidTaskUtils.spec:99',
    ].join('\n');

    const result = parseJestLuaOutput(input, {
      packageName: '@quenty/maid',
      repoRoot: REPO_ROOT,
    });

    expect(result).toHaveLength(1);
    expect(result[0].title).toBe(
      'Level1 > Level2 > Level3 > Level4 > deep test'
    );
  });

  it('emits no file when there is no location', () => {
    const input = [
      '  ● Suite > test without location',
      '',
      '    some error happened',
      '',
      'Test Suites: 1 failed, 1 total',
    ].join('\n');

    const result = parseJestLuaOutput(input, {
      packageName: '@quenty/maid',
      repoRoot: REPO_ROOT,
    });

    expect(result).toHaveLength(1);
    expect(result[0].file).toBeUndefined();
    expect(result[0].line).toBeUndefined();
  });

  it('emits no file when the location does not exist in the repo', () => {
    const input = [
      '  ● Suite > test one',
      '',
      '    Expected: 1',
      '',
      '      at ServerScriptService.unknownpkg.Shared.Bar.spec:10',
    ].join('\n');

    const result = parseJestLuaOutput(input, {
      packageName: '@quenty/unknownpkg',
      repoRoot: REPO_ROOT,
    });

    expect(result).toHaveLength(1);
    expect(result[0].file).toBeUndefined();
  });

  it('searches spec file for it() call when at location has no line number', async () => {
    const actualFs = await vi.importActual<typeof import('fs')>('fs');
    const { readFileSync } = await import('fs');
    const specContent = [
      'local require = require(script.Parent.loader).load(script)',
      '',
      'describe("Suite", function()',
      '  it("my test name", function()',
      '    -- test body',
      '  end)',
      'end)',
    ].join('\n');
    vi.mocked(readFileSync).mockImplementation(((
      filePath: PathOrFileDescriptor,
      options?: BufferEncoding
    ) =>
      String(filePath).endsWith('MaidTaskUtils.spec.lua')
        ? specContent
        : actualFs.readFileSync(filePath, options)) as typeof readFileSync);

    const input = [
      '  ● Suite › my test name',
      '',
      '    assertion failed',
      '',
      '      at ServerScriptService.maid.Shared.MaidTaskUtils.spec',
    ].join('\n');

    const result = parseJestLuaOutput(input, {
      packageName: '@quenty/maid',
      repoRoot: REPO_ROOT,
    });

    expect(result).toHaveLength(1);
    expect(result[0].file).toBe('src/maid/src/Shared/MaidTaskUtils.spec.lua');
    expect(result[0].line).toBe(4);
  });

  it('parses a runtime error with Stack Begin/Stack End', () => {
    const input = [
      'Error: attempt to index nil with "Connect"',
      'Stack Begin',
      "Script 'ServerScriptService.maid.Shared.MaidTaskUtils', Line 23",
      'Stack End',
    ].join('\n');

    const result = parseJestLuaOutput(input, {
      packageName: '@quenty/maid',
      repoRoot: REPO_ROOT,
    });

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      file: 'src/maid/src/Shared/MaidTaskUtils.lua',
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
      '      at ServerScriptService.maid.Shared.MaidTaskUtils.spec:10',
      '',
      'Error: attempt to call nil value',
      'Stack Begin',
      "Script 'ServerScriptService.maid.Shared.Maid', Line 5",
      'Stack End',
    ].join('\n');

    const result = parseJestLuaOutput(input, {
      packageName: '@quenty/maid',
      repoRoot: REPO_ROOT,
    });

    expect(result).toHaveLength(2);
    expect(result[0].title).toBe('Suite > assertion test');
    expect(result[0].source).toBe('jest-lua');
    expect(result[1].title).toBe('Runtime error');
    expect(result[1].message).toBe('Error: attempt to call nil value');
    expect(result[1].file).toBe('src/maid/src/Shared/Maid.lua');
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

    const result = parseJestLuaOutput(input, { packageName: '@quenty/maid' });

    expect(result).toEqual([]);
  });

  it('strips ANSI escape codes cleanly', () => {
    const input = [
      '  \x1b[31m●\x1b[39m \x1b[1mSuite > test\x1b[22m',
      '',
      '    \x1b[31mExpected: 1\x1b[39m',
      '    \x1b[32mReceived: 2\x1b[39m',
      '',
      '      at ServerScriptService.maid.Shared.MaidTaskUtils.spec:10',
    ].join('\n');

    const result = parseJestLuaOutput(input, {
      packageName: '@quenty/maid',
      repoRoot: REPO_ROOT,
    });

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

    const result = parseJestLuaOutput(input, { packageName: '@quenty/maid' });

    expect(result).toHaveLength(1);
    expect(result[0].title).toBe('Suite > incomplete test');
    expect(result[0].file).toBeUndefined();
  });

  it('handles empty input', () => {
    const result = parseJestLuaOutput('', { packageName: '@quenty/maid' });
    expect(result).toEqual([]);
  });

  describe('real CI logs', () => {
    it('unwraps chunk names and picks the innermost package frame of a runtime error', () => {
      // run 32500891927, saveslot
      const input = [
        `[string "ServerScriptService.saveslot.Server.HasSaveSlotsDataStore"]:1668: attempt to call missing method 'GetSubStore' of table`,
        '    Stack Begin',
        `    Script '[string "ServerScriptService.saveslot.Server.HasSaveSlotsDataStore"]', Line 1668 - function _stagePlaytime`,
        `    Script '[string "ServerScriptService.saveslot.Server.HasSaveSlotsDataStore"]', Line 1647 - function _flushPlaytime`,
        `    Script '[string "ServerScriptService.saveslot.Server.HasSaveSlotsDataStore"]', Line 1678 - function _endPlaySession`,
        `    Script '[string "ServerScriptService.saveslot.Server.HasSaveSlotsDataStore"]', Line 1609`,
        `    Script '[string "ServerScriptService.saveslot.node_modules.@quenty.adorneedata.node_modules.@quenty.attributeutils.node_modules.@quenty.baseobject.node_modules.@quenty.maid.Shared.Maid"]', Line 267 - function DoCleaning`,
        `    Script '[string "ServerScriptService.saveslot.node_modules.@quenty.adorneedata.node_modules.@quenty.attributeutils.node_modules.@quenty.baseobject.Shared.BaseObject"]', Line 40 - function Destroy`,
        `    Script '[string "ServerScriptService.saveslot.node_modules.@quenty.binder.Shared.Binder"]', Line 752 - function _remove`,
        `    Script '[string "ServerScriptService.saveslot.node_modules.@quenty.binder.Shared.Binder"]', Line 224`,
        '    Stack End',
      ].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: '@quenty/saveslot',
        repoRoot: REPO_ROOT,
      });

      expect(result).toHaveLength(1);
      expect(result[0].file).toBe(
        'src/saveslot/src/Server/HasSaveSlotsDataStore.lua'
      );
      expect(result[0].line).toBe(1668);
    });

    it('reads Jest frames without an `at` prefix', () => {
      // run 32500891927, saveslot
      const input = [
        '\x1b[1m\x1b[31m  \x1b[1m● \x1b[22m\x1b[1msave slot playtime › persists accrued playtime on the save that triggered the flush\x1b[39m\x1b[22m',
        '',
        "    attempt to call missing method 'GetSubStore' of table",
        '\x1b[2m\x1b[22m',
        '\x1b[2m      ServerScriptService.saveslot.Server.HasSaveSlotsDataStore:1668\x1b[22m',
        '',
        '\x1b[1m\x1b[31m  \x1b[1m● \x1b[22m\x1b[1msave slot playtime › keeps the replicated attribute and the stored value in step\x1b[39m\x1b[22m',
        '',
        "    attempt to call missing method 'GetSubStore' of table",
        '\x1b[2m\x1b[22m',
        '\x1b[2m      ServerScriptService.saveslot.Server.HasSaveSlotsDataStore:1668\x1b[22m',
        '',
      ].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: '@quenty/saveslot',
        repoRoot: REPO_ROOT,
      });

      expect(result).toHaveLength(2);
      expect(result.map((d) => [d.file, d.line, d.title])).toEqual([
        [
          'src/saveslot/src/Server/HasSaveSlotsDataStore.lua',
          1668,
          'save slot playtime › persists accrued playtime on the save that triggered the flush',
        ],
        [
          'src/saveslot/src/Server/HasSaveSlotsDataStore.lua',
          1668,
          'save slot playtime › keeps the replicated attribute and the stored value in step',
        ],
      ]);
      expect(result[0].message).toBe(
        "attempt to call missing method 'GetSubStore' of table"
      );
    });

    it('prefers the package under test over dependency frames', () => {
      // run 35638745222, gameproduct (test slug differs from the src/ directory)
      const input = [
        `[string "ServerScriptService.gameproduct.node_modules.@quenty.cmdrservice.node_modules.@quenty.templateprovider.Shared.TemplateProvider"]:726: [TemplateProvider.CmdrTemplateProviderServer.CloneTemplate] - Cannot provide template "CmdrExecutionTemplate"`,
        '    Stack Begin',
        `    Script '[string "ServerScriptService.gameproduct.node_modules.@quenty.cmdrservice.node_modules.@quenty.templateprovider.Shared.TemplateProvider"]', Line 726 - function CloneTemplate`,
        `    Script '[string "ServerScriptService.gameproduct.node_modules.@quenty.cmdrservice.Server.CmdrService"]', Line 144 - function RegisterCommand`,
        `    Script '[string "ServerScriptService.gameproduct.Server.Cmdr.GameProductCmdrService"]', Line 59 - function _registerCommands`,
        `    Script '[string "ServerScriptService.gameproduct.Server.Cmdr.GameProductCmdrService"]', Line 55 - function Start`,
        `    Script '[string "ServerScriptService.gameproduct.node_modules.@quenty.avatareditorutils.node_modules.@quenty.observablecollection.node_modules.@quenty.blend.node_modules.@quenty.playerthumbnailutils.node_modules.@quenty.playermock.node_modules.@quenty.servic..."]', Line 217`,
        '    Stack End',
      ].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: '@quenty/gameproductservice',
        repoRoot: REPO_ROOT,
      });

      expect(result).toHaveLength(1);
      expect(result[0].file).toBe(
        'src/gameproductservice/src/Server/Cmdr/GameProductCmdrService.lua'
      );
      expect(result[0].line).toBe(59);
    });

    it('does not let a sibling package frame land in the package under test', () => {
      // run 32500891927, saveslot, with a sibling package's frame on top
      const input = [
        `[string "ServerScriptService.saveslot.Server.HasSaveSlotsDataStore"]:1668: attempt to call missing method 'GetSubStore' of table`,
        '    Stack Begin',
        `    Script '[string "ServerScriptService.othersibling.Server.SaveSlotService"]', Line 10`,
        `    Script '[string "ServerScriptService.saveslot.Server.HasSaveSlotsDataStore"]', Line 1668 - function _stagePlaytime`,
        '    Stack End',
      ].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: '@quenty/saveslot',
        repoRoot: REPO_ROOT,
      });

      expect(result).toHaveLength(1);
      expect(result[0].file).toBe(
        'src/saveslot/src/Server/HasSaveSlotsDataStore.lua'
      );
      expect(result[0].line).toBe(1668);
    });

    it('maps dependency frames back to the dependency source package', () => {
      // run 35638745222, gameproduct
      const input = [
        `[string "ServerScriptService.gameproduct.node_modules.@quenty.cmdrservice.node_modules.@quenty.templateprovider.Shared.TemplateProvider"]:726: [TemplateProvider.CmdrTemplateProviderServer.CloneTemplate] - Cannot provide template "CmdrExecutionTemplate"`,
        '    Stack Begin',
        `    Script '[string "ServerScriptService.gameproduct.node_modules.@quenty.cmdrservice.node_modules.@quenty.templateprovider.Shared.TemplateProvider"]', Line 726 - function CloneTemplate`,
        `    Script '[string "ServerScriptService.gameproduct.node_modules.@quenty.cmdrservice.Server.CmdrService"]', Line 144 - function RegisterCommand`,
        `    Script '[string "ServerScriptService.gameproduct.node_modules.@quenty.gameconfig.Server.Cmdr.GameConfigCommandService"]', Line 48 - function _registerCommands`,
        `    Script '[string "ServerScriptService.gameproduct.node_modules.@quenty.gameconfig.Server.Cmdr.GameConfigCommandService"]', Line 37 - function Start`,
        `    Script '[string "ServerScriptService.gameproduct.node_modules.@quenty.avatareditorutils.node_modules.@quenty.observablecollection.node_modules.@quenty.blend.node_modules.@quenty.playerthumbnailutils.node_modules.@quenty.playermock.node_modules.@quenty.servic..."]', Line 217`,
        '    Stack End',
      ].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: '@quenty/gameproductservice',
        repoRoot: REPO_ROOT,
      });

      expect(result).toHaveLength(1);
      expect(result[0].file).toBe(
        'src/templateprovider/src/Shared/TemplateProvider.lua'
      );
      expect(result[0].line).toBe(726);
    });

    const studioBridgeHeader = [
      '\x1b[0m\x1b[7m\x1b[1m\x1b[31m FAIL \x1b[39m\x1b[22m\x1b[27m\x1b[0m \x1b[2mstudiobridge/Shared/\x1b[22m\x1b[1mActionRouter.spec\x1b[22m ',
      '  \x1b[1m● \x1b[22mTest suite failed to run',
      '',
    ];
    const studioBridgeFrames = [
      '      ServerScriptService.studiobridge.node_modules.@quenty.nevermore-test-runner.node_modules.@quentystudios.Jest._Index.jsdotlua_jest-runtime@3.10.0.jest-runtime:1263 function requireModule',
      '      ServerScriptService.studiobridge.node_modules.@quenty.nevermore-test-runner.node_modules.@quentystudios.Jest._Index.jsdotlua_jest-circus@3.10.0.jest-circus.circus.legacy-code-todo-rewrite.jestAdapter:113',
      '      ServerScriptService.studiobridge.node_modules.@quenty.nevermore-test-runner.node_modules.@quentystudios.Jest._Index.jsdotlua_promise@3.5.2.promise:172 function runExecutor',
      '',
      '\x1b[0m\x1b[7m\x1b[1m\x1b[31m FAIL \x1b[39m\x1b[22m\x1b[27m\x1b[0m \x1b[2mstudiobridge/Shared/\x1b[22m\x1b[1mBuiltInActions.spec\x1b[22m ',
    ];

    it('falls back to a chunk location inside the message', () => {
      // run 40424080351, studio-bridge
      const input = [
        ...studioBridgeHeader,
        `    ServerScriptService.studiobridge.node_modules.@quenty.nevermore-test-runner.node_modules.@quentystudios.Jest._Index.jsdotlua_jest-runtime@3.10.0.jest-runtime:1263: [string "ServerScriptService.studiobridge.node_modules.@quenty.nevermore-test-runner.node_modules.@quenty.loader"]:214: [Loader] - "Jest" is not available. Please`,
        '',
        ...studioBridgeFrames,
      ].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: '@quenty/studio-bridge',
        repoRoot: REPO_ROOT,
      });

      expect(result).toHaveLength(1);
      expect(result[0].title).toBe('Test suite failed to run');
      expect(result[0].file).toBe('src/loader/src/init.lua');
      expect(result[0].line).toBe(214);
    });

    it('emits no file when only vendored frames are present', () => {
      // run 40424080351, studio-bridge
      const input = [...studioBridgeHeader, ...studioBridgeFrames].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: '@quenty/studio-bridge',
        repoRoot: REPO_ROOT,
      });

      expect(result).toHaveLength(1);
      expect(result[0].title).toBe('Test suite failed to run');
      expect(result[0].file).toBeUndefined();
      expect(result[0].line).toBeUndefined();
    });
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
        {
          name: 'binder',
          className: 'Folder',
          filePaths: [`${repoRoot}/src/binder/default.project.json`],
          children: [
            {
              name: 'Shared',
              className: 'Folder',
              children: [
                {
                  name: 'Binder',
                  className: 'ModuleScript',
                  filePaths: [`${repoRoot}/src/binder/src/Shared/Binder.lua`],
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
        packageName: '@quenty/mypkg',
        sourcemapResolver: resolver,
      });

      expect(result).toHaveLength(1);
      expect(result[0].file).toBe('src/mypkg/src/Shared/Foo.spec.lua');
      expect(result[0].line).toBe(10);
    });

    it('uses sourcemap resolver for chunk-wrapped runtime error paths', () => {
      const input = [
        'Error: attempt to index nil',
        'Stack Begin',
        `Script '[string "ServerScriptService.mypkg.Shared.Foo.Foo.spec"]', Line 5`,
        'Stack End',
      ].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: '@quenty/mypkg',
        sourcemapResolver: resolver,
      });

      expect(result).toHaveLength(1);
      expect(result[0].file).toBe('src/mypkg/src/Shared/Foo.spec.lua');
      expect(result[0].line).toBe(5);
    });

    it('looks up dependency frames by their source package', () => {
      const input = [
        'Error: attempt to index nil',
        '    Stack Begin',
        `    Script '[string "ServerScriptService.mypkg.node_modules.@quenty.binder.Shared.Binder"]', Line 752 - function _remove`,
        '    Stack End',
      ].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: '@quenty/mypkg',
        sourcemapResolver: resolver,
      });

      expect(result).toHaveLength(1);
      expect(result[0].file).toBe('src/binder/src/Shared/Binder.lua');
      expect(result[0].line).toBe(752);
    });

    it('falls back to the repo layout when sourcemap has no mapping', () => {
      const input = [
        '  ● Suite > test one',
        '',
        '    Expected: 1',
        '    Received: 2',
        '',
        '      at ServerScriptService.observablecollection.Shared.ObservableList.spec:10',
      ].join('\n');

      const result = parseJestLuaOutput(input, {
        packageName: '@quenty/observablecollection',
        sourcemapResolver: resolver,
        repoRoot: REPO_ROOT,
      });

      expect(result).toHaveLength(1);
      expect(result[0].file).toBe(
        'src/observablecollection/src/Shared/ObservableList.spec.lua'
      );
    });
  });
});
