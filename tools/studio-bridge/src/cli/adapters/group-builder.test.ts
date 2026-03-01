/**
 * Unit tests for the group builder.
 */

import { describe, it, expect, vi } from 'vitest';
import { buildGroupCommands } from './group-builder.js';
import { CommandRegistry } from '../../commands/framework/command-registry.js';
import { defineCommand } from '../../commands/framework/define-command.js';
import { arg } from '../../commands/framework/arg-builder.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeRegistry(): CommandRegistry {
  const registry = new CommandRegistry();

  registry.register(
    defineCommand({
      group: 'console',
      name: 'exec',
      description: 'Execute code',
      category: 'execution',
      safety: 'mutate',
      scope: 'session',
      args: { code: arg.positional({ description: 'Code' }) },
      handler: async () => ({}),
    }),
  );

  registry.register(
    defineCommand({
      group: 'console',
      name: 'logs',
      description: 'View logs',
      category: 'execution',
      safety: 'read',
      scope: 'session',
      args: {},
      handler: async () => ({}),
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
      handler: async () => ({}),
    }),
  );

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

function createMockYargs() {
  const commands: any[] = [];

  const mock: any = {
    commands,
    command: vi.fn((cmd: any) => {
      commands.push(cmd);
      return mock;
    }),
    demandCommand: vi.fn(() => mock),
  };

  return mock;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('buildGroupCommands', () => {
  it('creates a group command for each unique group', () => {
    const registry = makeRegistry();
    const result = buildGroupCommands(registry);

    expect(result.groups).toHaveLength(2);
    const groupNames = result.groups.map((g) => (g.command as string).split(' ')[0]);
    expect(groupNames).toContain('console');
    expect(groupNames).toContain('process');
  });

  it('creates top-level commands for null-group definitions', () => {
    const registry = makeRegistry();
    const result = buildGroupCommands(registry);

    expect(result.topLevel).toHaveLength(1);
    expect(result.topLevel[0].command).toBe('serve');
  });

  it('group commands use <command> suffix', () => {
    const registry = makeRegistry();
    const result = buildGroupCommands(registry);

    const consoleMod = result.groups.find(
      (g) => (g.command as string).startsWith('console'),
    );
    expect(consoleMod!.command).toBe('console <command>');
  });

  it('group commands have descriptions', () => {
    const registry = makeRegistry();
    const result = buildGroupCommands(registry);

    const consoleMod = result.groups.find(
      (g) => (g.command as string).startsWith('console'),
    );
    expect(consoleMod!.describe).toBe('Execute code and view logs');
  });

  it('group builder registers subcommands', () => {
    const registry = makeRegistry();
    const result = buildGroupCommands(registry);

    const consoleMod = result.groups.find(
      (g) => (g.command as string).startsWith('console'),
    );
    const yargs = createMockYargs();
    (consoleMod!.builder as any)(yargs);

    // Should register 2 subcommands (exec, logs)
    expect(yargs.commands).toHaveLength(2);
  });

  it('returns empty arrays for empty registry', () => {
    const registry = new CommandRegistry();
    const result = buildGroupCommands(registry);

    expect(result.groups).toEqual([]);
    expect(result.topLevel).toEqual([]);
  });
});
