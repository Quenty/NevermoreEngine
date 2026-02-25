/**
 * Unit tests for the defineCommand factory and isCommandDefinition guard.
 */

import { describe, it, expect } from 'vitest';
import {
  COMMAND_BRAND,
  defineCommand,
  isCommandDefinition,
} from './define-command.js';
import { arg } from './arg-builder.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function sessionCommand() {
  return defineCommand({
    group: 'console',
    name: 'exec',
    description: 'Execute inline Luau code',
    category: 'execution',
    safety: 'mutate',
    scope: 'session',
    args: {
      code: arg.positional({ description: 'Luau source code' }),
    },
    handler: async (_session, _args) => ({ success: true }),
  });
}

function connectionCommand() {
  return defineCommand({
    group: 'process',
    name: 'list',
    description: 'List connected sessions',
    category: 'infrastructure',
    safety: 'read',
    scope: 'connection',
    args: {},
    handler: async (_connection) => ({ sessions: [] }),
  });
}

function standaloneCommand() {
  return defineCommand({
    group: null,
    name: 'serve',
    description: 'Start the bridge server',
    category: 'infrastructure',
    safety: 'none',
    scope: 'standalone',
    args: {},
    handler: async () => ({ port: 38741 }),
  });
}

// ---------------------------------------------------------------------------
// defineCommand
// ---------------------------------------------------------------------------

describe('defineCommand', () => {
  it('stamps brand symbol on session command', () => {
    const cmd = sessionCommand();
    expect(cmd[COMMAND_BRAND]).toBe(true);
  });

  it('stamps brand symbol on connection command', () => {
    const cmd = connectionCommand();
    expect(cmd[COMMAND_BRAND]).toBe(true);
  });

  it('stamps brand symbol on standalone command', () => {
    const cmd = standaloneCommand();
    expect(cmd[COMMAND_BRAND]).toBe(true);
  });

  it('preserves group, name, and description', () => {
    const cmd = sessionCommand();
    expect(cmd.group).toBe('console');
    expect(cmd.name).toBe('exec');
    expect(cmd.description).toBe('Execute inline Luau code');
  });

  it('preserves category and safety', () => {
    const cmd = sessionCommand();
    expect(cmd.category).toBe('execution');
    expect(cmd.safety).toBe('mutate');
  });

  it('preserves scope discriminant', () => {
    expect(sessionCommand().scope).toBe('session');
    expect(connectionCommand().scope).toBe('connection');
    expect(standaloneCommand().scope).toBe('standalone');
  });

  it('preserves args record', () => {
    const cmd = sessionCommand();
    expect(cmd.args).toHaveProperty('code');
    expect(cmd.args.code.kind).toBe('positional');
  });

  it('preserves handler function', () => {
    const cmd = sessionCommand();
    expect(typeof cmd.handler).toBe('function');
  });

  it('preserves optional mcp config', () => {
    const cmd = defineCommand({
      group: 'console',
      name: 'exec',
      description: 'Execute code',
      category: 'execution',
      safety: 'mutate',
      scope: 'session',
      args: {},
      handler: async () => ({ done: true }),
      mcp: {
        toolName: 'studio_console_exec',
        mapResult: (result) => [{ type: 'text', text: JSON.stringify(result) }],
      },
    });

    expect(cmd.mcp).toBeDefined();
    expect(cmd.mcp!.toolName).toBe('studio_console_exec');
  });

  it('preserves optional cli config', () => {
    const cmd = defineCommand({
      group: 'console',
      name: 'exec',
      description: 'Execute code',
      category: 'execution',
      safety: 'mutate',
      scope: 'session',
      args: {},
      handler: async () => ({ done: true }),
      cli: {
        formatResult: () => 'formatted',
      },
    });

    expect(cmd.cli).toBeDefined();
    expect(cmd.cli!.formatResult!({} as any, 'text')).toBe('formatted');
  });

  it('allows null group for top-level commands', () => {
    const cmd = standaloneCommand();
    expect(cmd.group).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// isCommandDefinition
// ---------------------------------------------------------------------------

describe('isCommandDefinition', () => {
  it('returns true for branded definition', () => {
    expect(isCommandDefinition(sessionCommand())).toBe(true);
  });

  it('returns true for all scope variants', () => {
    expect(isCommandDefinition(connectionCommand())).toBe(true);
    expect(isCommandDefinition(standaloneCommand())).toBe(true);
  });

  it('returns false for plain object', () => {
    expect(isCommandDefinition({ group: 'console', name: 'exec' })).toBe(false);
  });

  it('returns false for object with wrong brand value', () => {
    const fake = { [COMMAND_BRAND]: 'yes' };
    expect(isCommandDefinition(fake)).toBe(false);
  });

  it('returns false for null', () => {
    expect(isCommandDefinition(null)).toBe(false);
  });

  it('returns false for undefined', () => {
    expect(isCommandDefinition(undefined)).toBe(false);
  });

  it('returns false for non-object types', () => {
    expect(isCommandDefinition('string')).toBe(false);
    expect(isCommandDefinition(42)).toBe(false);
    expect(isCommandDefinition(true)).toBe(false);
  });

  it('returns false for function', () => {
    expect(isCommandDefinition(() => {})).toBe(false);
  });
});
