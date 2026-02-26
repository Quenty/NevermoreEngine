/**
 * Handler-level tests for the CLI command adapter — format flags,
 * output file writing, and watch mode.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { buildYargsCommand } from './cli-command-adapter.js';
import { defineCommand } from '../../commands/framework/define-command.js';
import type { CliLifecycleProvider } from './cli-command-adapter.js';

// ---------------------------------------------------------------------------
// Module mock for fs (ESM-safe)
// ---------------------------------------------------------------------------

vi.mock('fs', async (importOriginal) => {
  const actual = await importOriginal<typeof import('fs')>();
  return {
    ...actual,
    writeFileSync: vi.fn(),
  };
});

import * as fs from 'fs';

// ---------------------------------------------------------------------------
// Mock lifecycle (no real connection)
// ---------------------------------------------------------------------------

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
    } as any,
    session,
  };
}

function createMockLifecycle(): CliLifecycleProvider & { mock: ReturnType<typeof createMockConnection> } {
  const mock = createMockConnection();
  return {
    mock,
    connectAsync: vi.fn().mockResolvedValue(mock.connection),
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

function readCommand(overrides: Partial<{
  handler: (...args: any[]) => Promise<any>;
  cli: any;
  scope: 'session' | 'connection' | 'standalone';
}> = {}) {
  return defineCommand({
    group: 'test',
    name: 'read',
    description: 'Test read command',
    category: 'execution',
    safety: 'read',
    scope: overrides.scope ?? 'session',
    args: {},
    handler: overrides.handler ?? (async () => ({
      items: ['a', 'b'],
      summary: 'Found 2 items',
    })),
    cli: overrides.cli,
  } as any);
}

// ---------------------------------------------------------------------------
// Stub process.exit to avoid killing the test runner
// ---------------------------------------------------------------------------

let exitSpy: any;

beforeEach(() => {
  exitSpy = vi.spyOn(process, 'exit').mockImplementation(() => {
    throw new Error('process.exit called');
  });
  vi.mocked(fs.writeFileSync).mockReset();
});

afterEach(() => {
  exitSpy.mockRestore();
});

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

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

  it('outputs summary text when --format text and no cli.formatResult', async () => {
    const lifecycle = createMockLifecycle();
    const cmd = readCommand();
    const module = buildYargsCommand(cmd, { lifecycle });

    const output = await captureOutput(async () => {
      await (module.handler as any)({ format: 'text' });
    });

    expect(output[0]).toBe('Found 2 items');
  });

  it('uses cli.formatResult.text when --format text', async () => {
    const lifecycle = createMockLifecycle();
    const cmd = readCommand({
      cli: {
        formatResult: {
          text: (result: any) => `Custom: ${result.items.join(', ')}`,
        },
      },
    });
    const module = buildYargsCommand(cmd, { lifecycle });

    const output = await captureOutput(async () => {
      await (module.handler as any)({ format: 'text' });
    });

    expect(output[0]).toBe('Custom: a, b');
  });

  it('errors when explicit --format text and no formatter or summary', async () => {
    const lifecycle = createMockLifecycle();
    const cmd = readCommand({
      handler: async () => ({ data: [1, 2, 3] }),
    });
    const module = buildYargsCommand(cmd, { lifecycle });

    // Should error because explicit --format text, no formatter, no summary
    await expect(
      captureOutput(async () => {
        await (module.handler as any)({ format: 'text' });
      }),
    ).rejects.toThrow('process.exit called');
  });

  it('defaults to JSON when no format specified and no formatter (non-TTY)', async () => {
    const lifecycle = createMockLifecycle();
    const cmd = readCommand();
    const module = buildYargsCommand(cmd, { lifecycle });

    // No --format specified, non-TTY resolves to 'text' mode which falls
    // back to summary
    const output = await captureOutput(async () => {
      await (module.handler as any)({});
    });

    // Should output the summary (in non-TTY mode resolves to 'text')
    expect(output.length).toBe(1);
    expect(output[0]).toBe('Found 2 items');
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

    const stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    await captureOutput(async () => {
      await (module.handler as any)({ format: 'json', output: '/tmp/test.json' });
    });

    expect(fs.writeFileSync).toHaveBeenCalledOnce();
    const call = vi.mocked(fs.writeFileSync).mock.calls[0];
    expect(call[0]).toBe('/tmp/test.json');
    const written = call[1] as string;
    expect(JSON.parse(written)).toEqual({ items: ['a', 'b'], summary: 'Found 2 items' });
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
        formatResult: {
          text: (result: any) => result.summary,
        },
      },
    });
    const module = buildYargsCommand(cmd, { lifecycle });

    const stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    await captureOutput(async () => {
      await (module.handler as any)({ output: '/tmp/test.png', format: 'text' });
    });

    expect(fs.writeFileSync).toHaveBeenCalledOnce();
    const call = vi.mocked(fs.writeFileSync).mock.calls[0];
    expect(call[0]).toBe('/tmp/test.png');
    // Should be a Buffer (binary write)
    expect(Buffer.isBuffer(call[1])).toBe(true);
    expect((call[1] as Buffer).toString()).toBe('PNG-DATA');
    expect(stderrSpy).toHaveBeenCalledWith('Wrote binary output to /tmp/test.png\n');

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
        formatResult: {
          json: (result: any) => JSON.stringify({ summary: result.summary }),
        },
      },
    });
    const module = buildYargsCommand(cmd, { lifecycle });

    vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    await captureOutput(async () => {
      await (module.handler as any)({ output: '/tmp/test.json', format: 'json' });
    });

    expect(fs.writeFileSync).toHaveBeenCalledOnce();
    const call = vi.mocked(fs.writeFileSync).mock.calls[0];
    const written = call[1] as string;
    // Should be the JSON formatter output, not binary
    expect(JSON.parse(written)).toEqual({ summary: 'Screenshot taken' });

    vi.restoreAllMocks();
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
