import { describe, it, expect, vi } from 'vitest';
import yargs from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  buildYargsCommand,
  renderResult,
} from '../../../cli/adapters/cli-command-adapter.js';
import {
  formatGrepText,
  grepCommand,
  grepScriptsHandlerAsync,
} from './grep.js';

describe('grepScriptsHandlerAsync', () => {
  it('reports each script in a tree, with its matching lines under it', async () => {
    const session = {
      grepScriptsAsync: vi.fn().mockResolvedValue({
        matches: [
          {
            path: 'ServerScriptService.Main',
            segments: ['ServerScriptService', 'Main'],
            className: 'Script',
            line: 4,
            text: '\tlocal damage = 10',
          },
          {
            path: 'ServerScriptService.Main',
            segments: ['ServerScriptService', 'Main'],
            className: 'Script',
            line: 9,
            text: 'damage += 1',
          },
        ],
        searched: 12,
        total: 2,
        scripts: 1,
        truncated: false,
      }),
    } as any;

    const result = await grepScriptsHandlerAsync(session, {
      pattern: 'damage',
      caseSensitive: true,
    });

    expect(session.grepScriptsAsync).toHaveBeenCalledWith({
      pattern: 'damage',
      caseSensitive: true,
      root: undefined,
      query: undefined,
      selector: undefined,
      luaPattern: undefined,
      limit: undefined,
    });
    expect(result.summary).toBe('2 matching lines in 1 Script of 12 scripts');

    expect(OutputHelper.stripAnsi(formatGrepText(result)).split('\n')).toEqual([
      'ServerScriptService/',
      '  Main',
      '    4: local damage = 10',
      '    9: damage += 1',
    ]);
  });
});

describe('grep summary', () => {
  it('counts the matching lines past --limit', async () => {
    const match = {
      path: 'ServerScriptService.Main',
      segments: ['ServerScriptService', 'Main'],
      className: 'Script',
      line: 1,
      text: 'require(x)',
    };
    const session = {
      grepScriptsAsync: vi.fn().mockResolvedValue({
        matches: [match, match, match],
        searched: 340,
        total: 57,
        scripts: 12,
        truncated: true,
      }),
    } as any;

    const result = await grepScriptsHandlerAsync(session, {
      pattern: 'require',
      limit: 3,
    });

    expect(result.summary).toBe('3 of 57 matching lines in 12 of 340 scripts');
  });
});

describe('grep arguments', () => {
  it('takes the text as the positional and the query as --query', async () => {
    const session = {
      grepScriptsAsync: vi.fn().mockResolvedValue({
        matches: [],
        searched: 0,
        total: 0,
        scripts: 0,
        truncated: false,
      }),
    } as any;
    let parsed: any;
    await yargs([
      'grep',
      'TakeDamage',
      '--query',
      'is:ModuleScript',
      '--selector',
      'ModuleScript',
      '--root',
      'ReplicatedStorage',
    ])
      .command({
        ...buildYargsCommand(grepCommand),
        handler: (argv: any) => {
          parsed = argv;
        },
      })
      .parseAsync();

    await grepCommand.handler(session, parsed, {} as any);

    expect(session.grepScriptsAsync).toHaveBeenCalledWith({
      pattern: 'TakeDamage',
      query: 'is:ModuleScript',
      selector: 'ModuleScript',
      root: 'ReplicatedStorage',
      luaPattern: false,
      caseSensitive: false,
      limit: undefined,
    });
  });
});

describe('grep --format csv', () => {
  it('writes a row per matching line, with the line as it is', () => {
    const result = {
      matches: [
        {
          path: 'ServerScriptService.Main',
          segments: ['ServerScriptService', 'Main'],
          className: 'Script',
          line: 4,
          text: '	local damage = 10',
        },
      ],
      searched: 1,
      total: 1,
      scripts: 1,
      truncated: false,
      summary: '',
    };

    expect(renderResult(grepCommand, result, 'csv')).toBe(
      [
        'path,className,line,text',
        'ServerScriptService.Main,Script,4,\tlocal damage = 10',
        '',
      ].join('\n')
    );
  });
});
