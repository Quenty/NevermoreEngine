import { describe, it, expect, vi } from 'vitest';
import yargs from 'yargs';
import {
  buildYargsCommand,
  renderResult,
} from '../../../cli/adapters/cli-command-adapter.js';
import { toJsonSchema } from '../../framework/arg-builder.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  findCommand,
  findInstancesHandlerAsync,
  type FindResult,
} from './find.js';

function ref(...segments: string[]) {
  return { path: segments.join('.'), segments, className: 'Part' };
}

function body(result: FindResult): string {
  return OutputHelper.stripAnsi(findCommand.cli!.body!(result));
}

function createSession(result: unknown) {
  return { findInstancesAsync: vi.fn().mockResolvedValue(result) } as any;
}

async function runFindAsync(args: string[]): Promise<unknown> {
  const session = createSession({
    instances: [],
    searched: 0,
    total: 0,
    truncated: false,
  });
  let parsed: any;
  await yargs(['find', ...args])
    .command({
      ...buildYargsCommand(findCommand),
      handler: (argv: any) => {
        parsed = argv;
      },
    })
    .parseAsync();
  await findCommand.handler(session, parsed, {} as any);
  return session.findInstancesAsync.mock.calls[0][0];
}

describe('findInstancesHandlerAsync', () => {
  it('passes the query through and summarizes it', async () => {
    const session = createSession({
      instances: [ref('Workspace', 'RedSpawn')],
      searched: 120,
      total: 1,
      truncated: false,
    });

    const result = await findInstancesHandlerAsync(session, {
      query: 'spawn is:BasePart',
      root: 'Workspace',
    });

    expect(session.findInstancesAsync).toHaveBeenCalledWith({
      query: 'spawn is:BasePart',
      root: 'Workspace',
    });
    expect(result.summary).toBe('1 Part among 120 instances');
    expect(body(result)).toBe('Workspace/\n  RedSpawn');
  });

  it('counts no matches', async () => {
    const session = createSession({
      instances: [],
      searched: 816,
      total: 0,
      truncated: false,
    });

    const result = await findInstancesHandlerAsync(session, { query: 'x' });

    expect(result.summary).toBe('0 matches among 816 instances');
    expect(body(result)).toBe('');
  });

  it('counts the matches past the limit', async () => {
    const session = createSession({
      instances: [ref('Workspace', 'A')],
      searched: 11604,
      total: 1532,
      truncated: true,
    });

    const result = await findInstancesHandlerAsync(session, {
      selector: 'BasePart',
    });

    expect(result.summary).toBe('1 of 1,532 matches among 11,604 instances');
    expect(body(result)).toBe('Workspace/\n  A (Part)');
  });

  it('counts matches of mixed classes as matches', async () => {
    const session = createSession({
      instances: [
        ref('Workspace', 'A'),
        { ...ref('Workspace', 'B'), className: 'Model' },
      ],
      searched: 120,
      total: 2,
      truncated: false,
    });

    const result = await findInstancesHandlerAsync(session, { query: 'x' });

    expect(result.summary).toBe('2 matches among 120 instances');
    expect(body(result)).toBe('Workspace/\n  A (Part)\n  B (Model)');
  });

  it('needs something to search for', async () => {
    await expect(
      findInstancesHandlerAsync(createSession({}), { root: 'Workspace' })
    ).rejects.toMatchObject({
      message: 'Nothing to search for: no query was given.',
      fix: 'Give a query, --selector or --grep, e.g. is:Part.',
    });
  });
});

describe('find arguments', () => {
  it('joins an unquoted query back into one', async () => {
    expect(await runFindAsync(['is:BasePart', 'Anchored=true'])).toEqual(
      expect.objectContaining({ query: 'is:BasePart Anchored=true' })
    );
  });

  it('passes --selector, --grep and its text options', async () => {
    expect(
      await runFindAsync([
        '--selector',
        'Model > Part',
        '--grep',
        '^local',
        '--lua-pattern',
        '--root',
        'Workspace',
        '-n',
        '5',
      ])
    ).toEqual({
      query: undefined,
      selector: 'Model > Part',
      grep: '^local',
      luaPattern: true,
      caseSensitive: undefined,
      root: 'Workspace',
      limit: 5,
    });
  });

  it('no longer takes the old name, class and tag flags', () => {
    const schema = toJsonSchema(findCommand.args);

    expect(Object.keys(schema.properties).sort()).toEqual([
      'caseSensitive',
      'grep',
      'limit',
      'luaPattern',
      'query',
      'root',
      'selector',
    ]);
    expect(schema.properties.query.type).toBe('array');
  });
});

describe('find --format csv', () => {
  it('writes a row per instance, with its path and class', () => {
    const result: FindResult = {
      instances: [ref('Workspace', 'Door'), ref('Workspace', 'Wall, North')],
      searched: 10,
      total: 2,
      truncated: false,
      summary: '',
    };

    expect(renderResult(findCommand, result, 'csv')).toBe(
      [
        'path,className',
        'Workspace.Door,Part',
        '"Workspace.Wall, North",Part',
        '',
      ].join('\n')
    );
  });
});
