/**
 * Unit tests for the terminal command adapter.
 */

import { describe, it, expect } from 'vitest';
import { buildTerminalCommands } from './terminal-command-adapter.js';
import { CommandRegistry } from '../../../commands/framework/command-registry.js';
import { defineCommand } from '../../../commands/framework/define-command.js';
import { arg } from '../../../commands/framework/arg-builder.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeRegistry(): CommandRegistry {
  const registry = new CommandRegistry();

  registry.register(
    defineCommand({
      group: 'process',
      name: 'info',
      description: 'Query Studio state',
      category: 'execution',
      safety: 'read',
      scope: 'session',
      args: {},
      handler: async () => ({ state: 'Edit', summary: 'Mode: Edit' }),
    }),
  );

  registry.register(
    defineCommand({
      group: 'explorer',
      name: 'query',
      description: 'Query the DataModel',
      category: 'execution',
      safety: 'read',
      scope: 'session',
      args: {
        path: arg.positional({ description: 'DataModel path' }),
      },
      handler: async (_session: any, args: any) => ({
        path: args.path,
        summary: `Queried ${args.path}`,
      }),
    }),
  );

  registry.register(
    defineCommand({
      group: 'process',
      name: 'list',
      description: 'List sessions',
      category: 'infrastructure',
      safety: 'read',
      scope: 'connection',
      args: {},
      handler: async () => ({ sessions: [], summary: '0 sessions' }),
    }),
  );

  // Standalone — should be excluded
  registry.register(
    defineCommand({
      group: null,
      name: 'serve',
      description: 'Start server',
      category: 'infrastructure',
      safety: 'none',
      scope: 'standalone',
      args: {},
      handler: async () => ({}),
    }),
  );

  return registry;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('buildTerminalCommands', () => {
  describe('entries', () => {
    it('generates dot-command entries for session/connection commands', () => {
      const adapter = buildTerminalCommands(makeRegistry());

      const names = adapter.entries.map((e) => e.name);
      expect(names).toContain('.info');
      expect(names).toContain('.query');
      expect(names).toContain('.list');
    });

    it('excludes standalone commands', () => {
      const adapter = buildTerminalCommands(makeRegistry());

      const names = adapter.entries.map((e) => e.name);
      expect(names).not.toContain('.serve');
    });

    it('includes descriptions', () => {
      const adapter = buildTerminalCommands(makeRegistry());

      const infoEntry = adapter.entries.find((e) => e.name === '.info');
      expect(infoEntry!.description).toBe('Query Studio state');
    });

    it('includes usage for commands with positional args', () => {
      const adapter = buildTerminalCommands(makeRegistry());

      const queryEntry = adapter.entries.find((e) => e.name === '.query');
      expect(queryEntry!.usage).toBe('.query <path>');
    });
  });

  describe('dispatchAsync — session commands', () => {
    it('dispatches to session handler', async () => {
      const adapter = buildTerminalCommands(makeRegistry());
      const mockSession = {} as any;

      const result = await adapter.dispatchAsync(
        '.info',
        undefined,
        mockSession,
      );

      expect(result.handled).toBe(true);
      expect(result.output).toBe('Mode: Edit');
    });

    it('returns error when no session is available', async () => {
      const adapter = buildTerminalCommands(makeRegistry());

      const result = await adapter.dispatchAsync('.info', undefined, undefined);

      expect(result.handled).toBe(true);
      expect(result.error).toContain('No active session');
    });

    it('passes positional arg from remaining text', async () => {
      const adapter = buildTerminalCommands(makeRegistry());
      const mockSession = {} as any;

      const result = await adapter.dispatchAsync(
        '.query game.Workspace',
        undefined,
        mockSession,
      );

      expect(result.handled).toBe(true);
      expect(result.output).toBe('Queried game.Workspace');
    });
  });

  describe('dispatchAsync — connection commands', () => {
    it('dispatches to connection handler', async () => {
      const adapter = buildTerminalCommands(makeRegistry());
      const mockConnection = {} as any;

      const result = await adapter.dispatchAsync(
        '.list',
        mockConnection,
        undefined,
      );

      expect(result.handled).toBe(true);
      expect(result.output).toBe('0 sessions');
    });

    it('returns error when no connection is available', async () => {
      const adapter = buildTerminalCommands(makeRegistry());

      const result = await adapter.dispatchAsync('.list', undefined, undefined);

      expect(result.handled).toBe(true);
      expect(result.error).toContain('No bridge connection');
    });
  });

  describe('dispatchAsync — unknown commands', () => {
    it('returns handled=false for unknown commands', async () => {
      const adapter = buildTerminalCommands(makeRegistry());

      const result = await adapter.dispatchAsync(
        '.unknown',
        undefined,
        undefined,
      );

      expect(result.handled).toBe(false);
    });
  });

  describe('dispatchAsync — error handling', () => {
    it('catches handler errors and returns error result', async () => {
      const registry = new CommandRegistry();
      registry.register(
        defineCommand({
          group: 'test',
          name: 'fail',
          description: 'Always fails',
          category: 'execution',
          safety: 'read',
          scope: 'session',
          args: {},
          handler: async (): Promise<Record<string, unknown>> => {
            throw new Error('Something went wrong');
          },
        }),
      );

      const adapter = buildTerminalCommands(registry);
      const result = await adapter.dispatchAsync(
        '.fail',
        undefined,
        {} as any,
      );

      expect(result.handled).toBe(true);
      expect(result.error).toBe('Something went wrong');
    });
  });
});
