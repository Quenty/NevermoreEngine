/**
 * Handler-level tests for the CLI command adapter — format flags,
 * output file writing, and watch mode.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { buildYargsCommand } from './cli-command-adapter.js';
import { defineCommand } from '../../commands/framework/define-command.js';
import { arg } from '../../commands/framework/arg-builder.js';
import type { CliLifecycleProvider } from './cli-command-adapter.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { StudioBridgeError } from '../../messages/studio-bridge-error.js';

vi.mock('../cli-output-context.js', () => ({
  addWarning: vi.fn(),
  getWarnings: () => [],
  isJsonOutputEnabled: () => false,
  reportStaleHost: vi.fn(),
  warnIfPluginStaleAsync: vi.fn().mockResolvedValue(undefined),
}));

vi.mock('../plugin-freshness.js', () => ({
  ensureCurrentPluginAsync: vi.fn(async (_connection, session) => session),
  resolvePluginUpdatePolicy: () => 'error',
  setPluginUpdatePolicy: vi.fn(),
}));

vi.mock('fs', async (importOriginal) => {
  const actual = await importOriginal<typeof import('fs')>();
  return {
    ...actual,
    writeFileSync: vi.fn(),
  };
});

import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

function createMockSession() {
  return { sessionId: 'mock-session' };
}

function createMockConnection() {
  const session = createMockSession();
  return {
    connection: {
      resolveSessionAsync: vi.fn().mockResolvedValue(session),
      disconnectAsync: vi.fn().mockResolvedValue(undefined),
      listSessions: vi.fn().mockReturnValue([]),
      listInstances: vi.fn().mockReturnValue([]),
    } as any,
    session,
  };
}

function createMockLifecycle(): CliLifecycleProvider & {
  mock: ReturnType<typeof createMockConnection>;
} {
  const mock = createMockConnection();
  return {
    mock,
    connectAsync: vi.fn().mockResolvedValue(mock.connection),
  };
}

async function captureErrors(fn: () => Promise<void>): Promise<string[]> {
  const lines: string[] = [];
  const spy = vi.spyOn(console, 'error').mockImplementation((...args) => {
    lines.push(OutputHelper.stripAnsi(args.map(String).join(' ')));
  });
  try {
    await fn();
  } finally {
    spy.mockRestore();
  }
  return lines;
}

/** Capture console.log output during handler execution. */
async function captureOutput(fn: () => Promise<void>): Promise<string[]> {
  const logs: string[] = [];
  const origLog = console.log;
  console.log = (...args: unknown[]) => {
    logs.push(args.map(String).join(' '));
  };
  try {
    await fn();
  } finally {
    console.log = origLog;
  }
  return logs;
}

function readCommand(
  overrides: Partial<{
    handler: (...args: any[]) => Promise<any>;
    cli: any;
    scope: 'session' | 'connection' | 'standalone';
  }> = {}
) {
  return defineCommand({
    group: 'test',
    name: 'read',
    description: 'Test read command',
    category: 'execution',
    safety: 'read',
    scope: overrides.scope ?? 'session',
    args: {},
    handler:
      overrides.handler ??
      (async () => ({
        items: ['a', 'b'],
        summary: 'Found 2 items',
      })),
    cli: overrides.cli,
  } as any);
}

let exitSpy: any;

beforeEach(() => {
  OutputHelper.setDiagnosticsToStderr(true);
  exitSpy = vi.spyOn(process, 'exit').mockImplementation(() => {
    throw new Error('process.exit called');
  });
  vi.mocked(fs.writeFileSync).mockReset();
});

afterEach(() => {
  exitSpy.mockRestore();
});

describe('handler — format flags', () => {
  it('outputs JSON when --format json is specified', async () => {
    const lifecycle = createMockLifecycle();
    const cmd = readCommand();
    const module = buildYargsCommand(cmd, { lifecycle });

    const output = await captureOutput(async () => {
      await (module.handler as any)({ format: 'json' });
    });

    expect(output.length).toBe(1);
    const parsed = JSON.parse(output[0]);
    expect(parsed.items).toEqual(['a', 'b']);
    expect(parsed.summary).toBe('Found 2 items');
  });

  it('prints the summary alone for a command without a body', async () => {
    const lifecycle = createMockLifecycle();
    const cmd = readCommand();
    const module = buildYargsCommand(cmd, { lifecycle });

    const output = await captureOutput(async () => {
      await (module.handler as any)({ format: 'text' });
    });

    expect(output).toEqual([OutputHelper.formatDim('Found 2 items')]);
  });

  it('prints a report body with the summary dim as the last line', async () => {
    const lifecycle = createMockLifecycle();
    const cmd = readCommand({
      cli: {
        body: (result: any) => result.items.join('\n'),
      },
    });
    const module = buildYargsCommand(cmd, { lifecycle });

    const output = await captureOutput(async () => {
      await (module.handler as any)({});
    });

    expect(output).toEqual([
      `a\nb\n${OutputHelper.formatDim('Found 2 items')}`,
    ]);
  });

  it('prints the summary alone for an empty report body', async () => {
    const lifecycle = createMockLifecycle();
    const cmd = readCommand({ cli: { body: () => '' } });
    const module = buildYargsCommand(cmd, { lifecycle });

    const output = await captureOutput(async () => {
      await (module.handler as any)({});
    });

    expect(output).toEqual([OutputHelper.formatDim('Found 2 items')]);
  });

  it('prints a data body alone, with the summary on stderr', async () => {
    const lifecycle = createMockLifecycle();
    const cmd = readCommand({
      cli: {
        output: 'data',
        body: (result: any) => result.items.join('\n'),
      },
    });
    const module = buildYargsCommand(cmd, { lifecycle });
    const stderr = vi
      .spyOn(process.stderr, 'write')
      .mockImplementation(() => true);

    const output = await captureOutput(async () => {
      await (module.handler as any)({});
    });

    expect(output).toEqual(['a\nb']);
    expect(stderr).toHaveBeenCalledWith(
      `${OutputHelper.formatDim('Found 2 items')}\n`
    );
    stderr.mockRestore();
  });

  it("keeps the summary out of a data command's JSON on stderr", async () => {
    const lifecycle = createMockLifecycle();
    const cmd = readCommand({ cli: { output: 'data', body: () => 'a' } });
    const module = buildYargsCommand(cmd, { lifecycle });
    const stderr = vi
      .spyOn(process.stderr, 'write')
      .mockImplementation(() => true);

    const output = await captureOutput(async () => {
      await (module.handler as any)({ format: 'json' });
    });

    expect(JSON.parse(output[0]).summary).toBe('Found 2 items');
    expect(stderr).not.toHaveBeenCalled();
    stderr.mockRestore();
  });
});

describe('handler — output file writing', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('writes JSON to file when --output and --format json', async () => {
    const lifecycle = createMockLifecycle();
    const cmd = readCommand();
    const module = buildYargsCommand(cmd, { lifecycle });

    const stderrSpy = vi
      .spyOn(process.stderr, 'write')
      .mockImplementation(() => true);

    await captureOutput(async () => {
      await (module.handler as any)({
        format: 'json',
        output: '/tmp/test.json',
      });
    });

    expect(fs.writeFileSync).toHaveBeenCalledOnce();
    const call = vi.mocked(fs.writeFileSync).mock.calls[0];
    expect(call[0]).toBe('/tmp/test.json');
    const written = call[1] as string;
    expect(JSON.parse(written)).toEqual({
      items: ['a', 'b'],
      summary: 'Found 2 items',
    });
    expect(stderrSpy).toHaveBeenCalledWith('Wrote output to /tmp/test.json\n');

    stderrSpy.mockRestore();
  });

  it('writes binary when --output and binaryField is set', async () => {
    const lifecycle = createMockLifecycle();
    const base64Data = Buffer.from('PNG-DATA').toString('base64');
    const cmd = readCommand({
      handler: async () => ({
        data: base64Data,
        summary: 'Screenshot taken',
      }),
      cli: {
        binaryField: 'data',
      },
    });
    const module = buildYargsCommand(cmd, { lifecycle });

    const stderrSpy = vi
      .spyOn(process.stderr, 'write')
      .mockImplementation(() => true);

    await captureOutput(async () => {
      await (module.handler as any)({
        output: '/tmp/test.png',
        format: 'text',
      });
    });

    expect(fs.writeFileSync).toHaveBeenCalledOnce();
    const call = vi.mocked(fs.writeFileSync).mock.calls[0];
    expect(call[0]).toBe('/tmp/test.png');
    // Should be a Buffer (binary write)
    expect(Buffer.isBuffer(call[1])).toBe(true);
    expect((call[1] as Buffer).toString()).toBe('PNG-DATA');
    expect(stderrSpy).toHaveBeenCalledWith(
      'Wrote binary output to /tmp/test.png\n'
    );

    stderrSpy.mockRestore();
  });

  it('writes JSON (not binary) when --output --format json even with binaryField', async () => {
    const lifecycle = createMockLifecycle();
    const base64Data = Buffer.from('PNG-DATA').toString('base64');
    const cmd = readCommand({
      handler: async () => ({
        data: base64Data,
        summary: 'Screenshot taken',
      }),
      cli: {
        binaryField: 'data',
        json: (result: any) => JSON.stringify({ summary: result.summary }),
      },
    });
    const module = buildYargsCommand(cmd, { lifecycle });

    vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    await captureOutput(async () => {
      await (module.handler as any)({
        output: '/tmp/test.json',
        format: 'json',
      });
    });

    expect(fs.writeFileSync).toHaveBeenCalledOnce();
    const call = vi.mocked(fs.writeFileSync).mock.calls[0];
    const written = call[1] as string;
    // Should be the JSON formatter output, not binary
    expect(JSON.parse(written)).toEqual({ summary: 'Screenshot taken' });

    vi.restoreAllMocks();
  });
});

describe('handler — csv and directory output', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  const csvCli = {
    rows: (result: any) => ({
      columns: ['item', 'note'],
      rows: result.items.map((item: string) => [item, `${item}, done`]),
    }),
  };
  const itemsCsv = ['item,note', 'a,"a, done"', 'b,"b, done"', ''].join('\n');

  it('writes CSV when --output ends in .csv', async () => {
    const lifecycle = createMockLifecycle();
    const module = buildYargsCommand(readCommand({ cli: csvCli }), {
      lifecycle,
    });
    vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    await captureOutput(async () => {
      await (module.handler as any)({ output: '/tmp/items.CSV' });
    });

    const call = vi.mocked(fs.writeFileSync).mock.calls[0];
    expect(call[1]).toBe(itemsCsv);
  });

  it('prints CSV with --format csv', async () => {
    const lifecycle = createMockLifecycle();
    const module = buildYargsCommand(readCommand({ cli: csvCli }), {
      lifecycle,
    });

    const logs = await captureOutput(async () => {
      await (module.handler as any)({ format: 'csv' });
    });

    expect(logs).toEqual([itemsCsv]);
  });

  it('says a command without rows has no table for --format csv', async () => {
    const lifecycle = createMockLifecycle();
    const handler = vi.fn();
    const module = buildYargsCommand(readCommand({ handler }), { lifecycle });
    const errors = await captureErrors(async () => {
      await expect((module.handler as any)({ format: 'csv' })).rejects.toThrow(
        'process.exit called'
      );
    });

    expect(errors).toEqual([
      "'test read' has no table to write as CSV.",
      'Use --format text or json.',
    ]);
    expect(handler).not.toHaveBeenCalled();
  });

  it('keeps an explicit --format over the .csv extension', async () => {
    const lifecycle = createMockLifecycle();
    const module = buildYargsCommand(readCommand({ cli: csvCli }), {
      lifecycle,
    });
    vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    await captureOutput(async () => {
      await (module.handler as any)({
        output: '/tmp/items.csv',
        format: 'json',
      });
    });

    const call = vi.mocked(fs.writeFileSync).mock.calls[0];
    expect(JSON.parse(call[1] as string).items).toEqual(['a', 'b']);
  });

  it('writes the files into the --output directory and prints the text', async () => {
    const lifecycle = createMockLifecycle();
    const module = buildYargsCommand(
      readCommand({
        cli: {
          files: (result: any) =>
            result.items.map((item: string) => ({
              relativePath: `${item}.txt`,
              data: item,
            })),
        },
      }),
      { lifecycle }
    );
    vi.spyOn(process.stderr, 'write').mockImplementation(() => true);
    const outputDir = path.join(os.tmpdir(), `adapter-dir-${process.pid}`);

    const logs = await captureOutput(async () => {
      await (module.handler as any)({ output: outputDir });
    });

    const written = vi
      .mocked(fs.writeFileSync)
      .mock.calls.map((call) => call[0]);
    expect(written).toEqual([
      path.join(outputDir, 'a.txt'),
      path.join(outputDir, 'b.txt'),
    ]);
    expect(logs).toEqual(['Found 2 items']);
    fs.rmSync(outputDir, { recursive: true, force: true });
  });
});

describe('handler — standalone scope', () => {
  it('does not connect for standalone commands', async () => {
    const lifecycle = createMockLifecycle();
    const cmd = defineCommand({
      group: null,
      name: 'standalone',
      description: 'Standalone test',
      category: 'infrastructure',
      safety: 'none',
      scope: 'standalone',
      args: {},
      handler: async () => ({ ok: true, summary: 'done' }),
    });
    const module = buildYargsCommand(cmd, { lifecycle });

    const output = await captureOutput(async () => {
      await (module.handler as any)({ format: 'text' });
    });

    expect(lifecycle.connectAsync).not.toHaveBeenCalled();
    expect(output[0]).toBe('done');
  });

  it('hands everything after -- to a passthrough arg as strings', async () => {
    const handler = vi.fn(async () => ({ summary: 'done' }));
    const cmd = defineCommand({
      group: null,
      name: 'standalone',
      description: 'Standalone test',
      category: 'infrastructure',
      safety: 'none',
      scope: 'standalone',
      args: { scriptArgs: arg.passthrough({ description: 'Script args' }) },
      handler,
    });
    const module = buildYargsCommand(cmd);

    await captureOutput(async () => {
      await (module.handler as any)({ format: 'text', '--': ['Player1', 3] });
    });

    expect(handler).toHaveBeenCalledWith({ scriptArgs: ['Player1', '3'] });
  });
});

describe('handler — connection lifecycle', () => {
  it('disconnects after handler completes', async () => {
    const lifecycle = createMockLifecycle();
    const cmd = readCommand();
    const module = buildYargsCommand(cmd, { lifecycle });

    await captureOutput(async () => {
      await (module.handler as any)({ format: 'json' });
    });

    expect(lifecycle.mock.connection.disconnectAsync).toHaveBeenCalledOnce();
  });
});

describe('handler — streamed watch', () => {
  it('runs cli.watch on the session instead of the handler', async () => {
    const lifecycle = createMockLifecycle();
    const handler = vi.fn();
    const watchHandler = vi.fn(async (_session, _args, stream) => {
      stream.write('change\n');
    });
    const cmd = buildYargsCommand(
      readCommand({
        handler,
        cli: { watch: { description: 'Stream', handler: watchHandler } },
      }),
      { lifecycle }
    );
    const written: unknown[] = [];
    const writeSpy = vi
      .spyOn(process.stdout, 'write')
      .mockImplementation((chunk) => written.push(chunk) > 0);

    try {
      await (cmd.handler as any)({ watch: true, format: 'json' });
    } finally {
      writeSpy.mockRestore();
    }

    expect(handler).not.toHaveBeenCalled();
    expect(watchHandler).toHaveBeenCalledWith(
      lifecycle.mock.session,
      {},
      expect.objectContaining({ format: 'json' })
    );
    expect(written).toEqual(['change\n']);
    expect(lifecycle.mock.connection.disconnectAsync).toHaveBeenCalled();
  });
});

describe('handler — errors', () => {
  const outdatedPlugin = () =>
    new StudioBridgeError({
      code: 'PLUGIN_OUTDATED',
      message: "The studio-bridge plugin in 'Baseplate' is out of date.",
      fix: 'Run the command again with --update-plugin.',
      cause: 'Installed plugin build ff77f7, this CLI needs 1aa54d',
    });

  async function runFailingAsync(
    error: unknown,
    argv: Record<string, unknown> = {}
  ): Promise<{ stdout: string[]; stderr: string[] }> {
    const cmd = buildYargsCommand(
      readCommand({
        handler: async () => {
          throw error;
        },
      }),
      { lifecycle: createMockLifecycle() }
    );
    let stdout: string[] = [];
    const stderr = await captureErrors(async () => {
      stdout = await captureOutput(async () => {
        await expect((cmd.handler as any)(argv)).rejects.toThrow(
          'process.exit called'
        );
      });
    });
    return { stdout, stderr };
  }

  beforeEach(() => {
    OutputHelper.setVerbose(false);
  });

  it('prints an expected failure as its message, then its fix', async () => {
    const { stderr } = await runFailingAsync(outdatedPlugin());

    expect(stderr).toEqual([
      "The studio-bridge plugin in 'Baseplate' is out of date.",
      'Run the command again with --update-plugin.',
    ]);
  });

  it('prints the cause of an expected failure only under --verbose', async () => {
    OutputHelper.setVerbose(true);

    const { stderr } = await runFailingAsync(outdatedPlugin());

    expect(stderr).toEqual([
      "The studio-bridge plugin in 'Baseplate' is out of date.",
      'Run the command again with --update-plugin.',
      'Installed plugin build ff77f7, this CLI needs 1aa54d',
    ]);
  });

  it('puts the code, error and fix in JSON output', async () => {
    const { stdout } = await runFailingAsync(outdatedPlugin(), {
      format: 'json',
    });

    expect(JSON.parse(stdout[0])).toEqual({
      success: false,
      code: 'PLUGIN_OUTDATED',
      error: "The studio-bridge plugin in 'Baseplate' is out of date.",
      fix: 'Run the command again with --update-plugin.',
    });
  });

  it('prints anything else as an unexpected error, by its first line', async () => {
    const { stderr } = await runFailingAsync(
      new TypeError("Cannot read properties of undefined (reading 'x')")
    );

    expect(stderr).toEqual([
      "Unexpected error: Cannot read properties of undefined (reading 'x'). Run with --verbose for details.",
    ]);
  });

  it('prints the stack of an unexpected error under --verbose', async () => {
    OutputHelper.setVerbose(true);

    const { stderr } = await runFailingAsync(new Error('Boom'));

    expect(stderr[0]).toBe('Unexpected error: Boom.');
    expect(stderr[1]).toMatch(/^Error: Boom\n\s+at /);
  });

  it('marks an unexpected error in JSON output', async () => {
    const { stdout } = await runFailingAsync(new Error('Boom'), {
      format: 'json',
    });

    expect(JSON.parse(stdout[0])).toEqual({
      success: false,
      code: 'UNEXPECTED_ERROR',
      error: 'Unexpected error: Boom. Run with --verbose for details.',
    });
  });

  it('says what replaced a removed option, without running the command', async () => {
    const lifecycle = createMockLifecycle();
    const handler = vi.fn();
    const cmd = buildYargsCommand(
      readCommand({
        handler,
        cli: { removedOptions: { class: 'Put is:Part in the query instead.' } },
      }),
      { lifecycle }
    );

    const output = await captureOutput(async () => {
      await expect(
        (cmd.handler as any)({ format: 'json', class: 'Part' })
      ).rejects.toThrow('process.exit called');
    });

    expect(JSON.parse(output[0])).toEqual({
      success: false,
      code: 'REMOVED_OPTION',
      error: '--class was removed.',
      fix: 'Put is:Part in the query instead.',
    });
    expect(handler).not.toHaveBeenCalled();
  });
});
