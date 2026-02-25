/**
 * Unit tests for the CLI command adapter.
 */

import { describe, it, expect, vi } from 'vitest';
import { buildYargsCommand } from './cli-command-adapter.js';
import { defineCommand, type CommandDefinition } from '../../commands/framework/define-command.js';
import { arg } from '../../commands/framework/arg-builder.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function sessionCommand(
  overrides: Partial<{ name: string; safety: 'read' | 'mutate' | 'none' }> = {},
): CommandDefinition {
  return defineCommand({
    group: 'console',
    name: overrides.name ?? 'exec',
    description: 'Execute code',
    category: 'execution',
    safety: overrides.safety ?? 'mutate',
    scope: 'session',
    args: {
      code: arg.positional({ description: 'Luau source code' }),
      timeout: arg.option({ description: 'Timeout', type: 'number', alias: 'T' }),
    },
    handler: async (_session, _args) => ({ success: true }),
  });
}

function standaloneCommand(): CommandDefinition {
  return defineCommand({
    group: null,
    name: 'serve',
    description: 'Start the bridge server',
    category: 'infrastructure',
    safety: 'none',
    scope: 'standalone',
    args: {
      port: arg.option({ description: 'Port number', type: 'number', default: 38741 }),
    },
    handler: async () => ({ started: true }),
  });
}

function connectionCommand(): CommandDefinition {
  return defineCommand({
    group: 'process',
    name: 'list',
    description: 'List sessions',
    category: 'infrastructure',
    safety: 'read',
    scope: 'connection',
    args: {},
    handler: async () => ({ sessions: [] }),
  });
}

/** Mock yargs Argv object that records calls. */
function createMockYargs() {
  const positionals: Record<string, any> = {};
  const options: Record<string, any> = {};

  const mock: any = {
    positionals,
    options,
    positional: vi.fn((name: string, opts: any) => {
      positionals[name] = opts;
      return mock;
    }),
    option: vi.fn((name: string, opts: any) => {
      options[name] = opts;
      return mock;
    }),
    demandCommand: vi.fn(() => mock),
  };

  return mock;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('buildYargsCommand', () => {
  describe('command string', () => {
    it('includes positional args in command string', () => {
      const module = buildYargsCommand(sessionCommand());
      expect(module.command).toBe('exec <code>');
    });

    it('produces simple command string with no positionals', () => {
      const module = buildYargsCommand(standaloneCommand());
      expect(module.command).toBe('serve');
    });

    it('uses command description', () => {
      const module = buildYargsCommand(sessionCommand());
      expect(module.describe).toBe('Execute code');
    });
  });

  describe('builder — arg registration', () => {
    it('registers positional args', () => {
      const module = buildYargsCommand(sessionCommand());
      const yargs = createMockYargs();
      (module.builder as any)(yargs);

      expect(yargs.positionals.code).toBeDefined();
      expect(yargs.positionals.code.describe).toBe('Luau source code');
      expect(yargs.positionals.code.type).toBe('string');
      expect(yargs.positionals.code.demandOption).toBe(true);
    });

    it('registers command-specific options', () => {
      const module = buildYargsCommand(sessionCommand());
      const yargs = createMockYargs();
      (module.builder as any)(yargs);

      expect(yargs.options.timeout).toBeDefined();
      expect(yargs.options.timeout.describe).toBe('Timeout');
      expect(yargs.options.timeout.type).toBe('number');
      expect(yargs.options.timeout.alias).toBe('T');
    });
  });

  describe('builder — universal args', () => {
    it('injects --target and --context for session-scoped commands', () => {
      const module = buildYargsCommand(sessionCommand());
      const yargs = createMockYargs();
      (module.builder as any)(yargs);

      expect(yargs.options.target).toBeDefined();
      expect(yargs.options.target.alias).toBe('t');
      expect(yargs.options.context).toBeDefined();
    });

    it('injects --target and --context for connection-scoped commands', () => {
      const module = buildYargsCommand(connectionCommand());
      const yargs = createMockYargs();
      (module.builder as any)(yargs);

      expect(yargs.options.target).toBeDefined();
      expect(yargs.options.context).toBeDefined();
    });

    it('does not inject --target for standalone commands', () => {
      const module = buildYargsCommand(standaloneCommand());
      const yargs = createMockYargs();
      (module.builder as any)(yargs);

      expect(yargs.options.target).toBeUndefined();
      expect(yargs.options.context).toBeUndefined();
    });

    it('always injects --format, --output, --open', () => {
      const module = buildYargsCommand(standaloneCommand());
      const yargs = createMockYargs();
      (module.builder as any)(yargs);

      expect(yargs.options.format).toBeDefined();
      expect(yargs.options.output).toBeDefined();
      expect(yargs.options.open).toBeDefined();
    });

    it('injects --watch and --interval for read-safety commands', () => {
      const module = buildYargsCommand(connectionCommand()); // safety: 'read'
      const yargs = createMockYargs();
      (module.builder as any)(yargs);

      expect(yargs.options.watch).toBeDefined();
      expect(yargs.options.watch.alias).toBe('w');
      expect(yargs.options.interval).toBeDefined();
      expect(yargs.options.interval.default).toBe(1000);
    });

    it('does not inject --watch for mutate-safety commands', () => {
      const module = buildYargsCommand(sessionCommand({ safety: 'mutate' }));
      const yargs = createMockYargs();
      (module.builder as any)(yargs);

      expect(yargs.options.watch).toBeUndefined();
      expect(yargs.options.interval).toBeUndefined();
    });
  });

  describe('handler — standalone', () => {
    it('calls standalone handler with extracted args', async () => {
      const handler = vi.fn().mockResolvedValue({ started: true });
      const cmd = defineCommand({
        group: null,
        name: 'serve',
        description: 'Start server',
        category: 'infrastructure',
        safety: 'none',
        scope: 'standalone',
        args: {
          port: arg.option({ description: 'Port', type: 'number', default: 38741 }),
        },
        handler,
      });

      const module = buildYargsCommand(cmd);
      await (module.handler as any)({ port: 9999, verbose: false, timeout: 120000 });

      expect(handler).toHaveBeenCalledWith({ port: 9999 });
    });
  });
});
