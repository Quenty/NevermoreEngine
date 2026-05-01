/**
 * Unit tests for the CommandRegistry.
 */

import { describe, it, expect } from 'vitest';
import { CommandRegistry } from './command-registry.js';
import { defineCommand } from './define-command.js';

function makeCommand(
  overrides: Partial<{
    group: string | null;
    name: string;
    category: 'execution' | 'infrastructure';
    safety: 'read' | 'mutate' | 'none';
    scope: 'session' | 'connection' | 'standalone';
  }> = {}
) {
  const scope = overrides.scope ?? 'session';

  const base = {
    group:
      overrides.group === undefined
        ? ('console' as string | null)
        : overrides.group,
    name: overrides.name ?? 'exec',
    description: 'Test command',
    category: overrides.category ?? ('execution' as const),
    safety: overrides.safety ?? ('mutate' as const),
    args: {},
  };

  if (scope === 'session') {
    return defineCommand({
      ...base,
      scope: 'session',
      handler: async () => ({}),
    });
  } else if (scope === 'connection') {
    return defineCommand({
      ...base,
      scope: 'connection',
      handler: async () => ({}),
    });
  } else {
    return defineCommand({
      ...base,
      scope: 'standalone',
      handler: async () => ({}),
    });
  }
}

describe('CommandRegistry', () => {
  describe('register / getAll', () => {
    it('registers and retrieves commands', () => {
      const registry = new CommandRegistry();
      const cmd = makeCommand();
      registry.register(cmd);

      expect(registry.getAll()).toHaveLength(1);
      expect(registry.getAll()[0]).toBe(cmd);
    });

    it('maintains insertion order', () => {
      const registry = new CommandRegistry();
      const a = makeCommand({ name: 'alpha' });
      const b = makeCommand({ name: 'beta' });
      const c = makeCommand({ name: 'charlie' });

      registry.register(a);
      registry.register(b);
      registry.register(c);

      const names = registry.getAll().map((d) => d.name);
      expect(names).toEqual(['alpha', 'beta', 'charlie']);
    });

    it('returns empty array when no commands registered', () => {
      const registry = new CommandRegistry();
      expect(registry.getAll()).toEqual([]);
    });
  });

  describe('getByGroup', () => {
    it('filters by group name', () => {
      const registry = new CommandRegistry();
      registry.register(makeCommand({ group: 'console', name: 'exec' }));
      registry.register(makeCommand({ group: 'console', name: 'logs' }));
      registry.register(makeCommand({ group: 'process', name: 'list' }));

      const consoleCommands = registry.getByGroup('console');
      expect(consoleCommands).toHaveLength(2);
      expect(consoleCommands.map((c) => c.name)).toEqual(['exec', 'logs']);
    });

    it('returns empty array for unknown group', () => {
      const registry = new CommandRegistry();
      registry.register(makeCommand({ group: 'console', name: 'exec' }));

      expect(registry.getByGroup('nonexistent')).toEqual([]);
    });
  });

  describe('getGroups', () => {
    it('returns unique group names', () => {
      const registry = new CommandRegistry();
      registry.register(makeCommand({ group: 'console', name: 'exec' }));
      registry.register(makeCommand({ group: 'console', name: 'logs' }));
      registry.register(makeCommand({ group: 'process', name: 'list' }));

      const groups = registry.getGroups();
      expect(groups).toEqual(['console', 'process']);
    });

    it('excludes null group (top-level commands)', () => {
      const registry = new CommandRegistry();
      registry.register(
        makeCommand({ group: null, name: 'serve', scope: 'standalone' })
      );
      registry.register(makeCommand({ group: 'console', name: 'exec' }));

      const groups = registry.getGroups();
      expect(groups).toEqual(['console']);
    });

    it('returns empty array when no groups', () => {
      const registry = new CommandRegistry();
      expect(registry.getGroups()).toEqual([]);
    });
  });

  describe('getTopLevel', () => {
    it('returns commands with null group', () => {
      const registry = new CommandRegistry();
      registry.register(
        makeCommand({ group: null, name: 'serve', scope: 'standalone' })
      );
      registry.register(
        makeCommand({ group: null, name: 'mcp', scope: 'standalone' })
      );
      registry.register(makeCommand({ group: 'console', name: 'exec' }));

      const topLevel = registry.getTopLevel();
      expect(topLevel).toHaveLength(2);
      expect(topLevel.map((c) => c.name)).toEqual(['serve', 'mcp']);
    });

    it('returns empty array when no top-level commands', () => {
      const registry = new CommandRegistry();
      registry.register(makeCommand({ group: 'console', name: 'exec' }));

      expect(registry.getTopLevel()).toEqual([]);
    });
  });

  describe('getByCategory', () => {
    it('filters by category', () => {
      const registry = new CommandRegistry();
      registry.register(makeCommand({ name: 'exec', category: 'execution' }));
      registry.register(
        makeCommand({ name: 'list', category: 'infrastructure' })
      );
      registry.register(makeCommand({ name: 'logs', category: 'execution' }));

      const execution = registry.getByCategory('execution');
      expect(execution).toHaveLength(2);
      expect(execution.map((c) => c.name)).toEqual(['exec', 'logs']);
    });
  });

  describe('get', () => {
    it('finds by group and name', () => {
      const registry = new CommandRegistry();
      const cmd = makeCommand({ group: 'console', name: 'exec' });
      registry.register(cmd);

      expect(registry.get('console', 'exec')).toBe(cmd);
    });

    it('finds top-level commands with null group', () => {
      const registry = new CommandRegistry();
      const cmd = makeCommand({
        group: null,
        name: 'serve',
        scope: 'standalone',
      });
      registry.register(cmd);

      expect(registry.get(null, 'serve')).toBe(cmd);
    });

    it('returns undefined for missing command', () => {
      const registry = new CommandRegistry();
      expect(registry.get('console', 'nonexistent')).toBeUndefined();
    });

    it('returns undefined when group matches but name does not', () => {
      const registry = new CommandRegistry();
      registry.register(makeCommand({ group: 'console', name: 'exec' }));

      expect(registry.get('console', 'logs')).toBeUndefined();
    });
  });
});
