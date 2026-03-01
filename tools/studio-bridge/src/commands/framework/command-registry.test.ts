/**
 * Unit tests for the CommandRegistry.
 */

import { describe, it, expect, vi, afterEach } from 'vitest';
import { mkdtemp, mkdir, rm } from 'fs/promises';
import { join } from 'path';
import { tmpdir } from 'os';
import { CommandRegistry } from './command-registry.js';
import { defineCommand } from './define-command.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeCommand(
  overrides: Partial<{
    group: string | null;
    name: string;
    category: 'execution' | 'infrastructure';
    safety: 'read' | 'mutate' | 'none';
    scope: 'session' | 'connection' | 'standalone';
  }> = {},
) {
  const scope = overrides.scope ?? 'session';

  const base = {
    group: overrides.group === undefined ? 'console' as string | null : overrides.group,
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

// ---------------------------------------------------------------------------
// register / getAll
// ---------------------------------------------------------------------------

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

  // -----------------------------------------------------------------------
  // getByGroup
  // -----------------------------------------------------------------------

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

  // -----------------------------------------------------------------------
  // getGroups
  // -----------------------------------------------------------------------

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
      registry.register(makeCommand({ group: null, name: 'serve', scope: 'standalone' }));
      registry.register(makeCommand({ group: 'console', name: 'exec' }));

      const groups = registry.getGroups();
      expect(groups).toEqual(['console']);
    });

    it('returns empty array when no groups', () => {
      const registry = new CommandRegistry();
      expect(registry.getGroups()).toEqual([]);
    });
  });

  // -----------------------------------------------------------------------
  // getTopLevel
  // -----------------------------------------------------------------------

  describe('getTopLevel', () => {
    it('returns commands with null group', () => {
      const registry = new CommandRegistry();
      registry.register(makeCommand({ group: null, name: 'serve', scope: 'standalone' }));
      registry.register(makeCommand({ group: null, name: 'mcp', scope: 'standalone' }));
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

  // -----------------------------------------------------------------------
  // getByCategory
  // -----------------------------------------------------------------------

  describe('getByCategory', () => {
    it('filters by category', () => {
      const registry = new CommandRegistry();
      registry.register(makeCommand({ name: 'exec', category: 'execution' }));
      registry.register(makeCommand({ name: 'list', category: 'infrastructure' }));
      registry.register(makeCommand({ name: 'logs', category: 'execution' }));

      const execution = registry.getByCategory('execution');
      expect(execution).toHaveLength(2);
      expect(execution.map((c) => c.name)).toEqual(['exec', 'logs']);
    });
  });

  // -----------------------------------------------------------------------
  // get
  // -----------------------------------------------------------------------

  describe('get', () => {
    it('finds by group and name', () => {
      const registry = new CommandRegistry();
      const cmd = makeCommand({ group: 'console', name: 'exec' });
      registry.register(cmd);

      expect(registry.get('console', 'exec')).toBe(cmd);
    });

    it('finds top-level commands with null group', () => {
      const registry = new CommandRegistry();
      const cmd = makeCommand({ group: null, name: 'serve', scope: 'standalone' });
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

  // -----------------------------------------------------------------------
  // discoverAsync
  // -----------------------------------------------------------------------

  describe('discoverAsync', () => {
    let tmpDir: string;

    afterEach(async () => {
      if (tmpDir) {
        await rm(tmpDir, { recursive: true, force: true });
      }
    });

    it('discovers grouped commands from <group>/<name>/<name> pattern', async () => {
      tmpDir = await mkdtemp(join(tmpdir(), 'registry-'));
      await mkdir(join(tmpDir, 'console', 'exec'), { recursive: true });
      await mkdir(join(tmpDir, 'console', 'logs'), { recursive: true });

      const execCmd = makeCommand({ group: 'console', name: 'exec' });
      const logsCmd = makeCommand({ group: 'console', name: 'logs' });

      const importFn = vi.fn().mockImplementation(async (path: string) => {
        if (path.includes(join('exec', 'exec.'))) {
          return { command: execCmd };
        }
        if (path.includes(join('logs', 'logs.'))) {
          return { command: logsCmd };
        }
        throw new Error('Not found');
      });

      const registry = await CommandRegistry.discoverAsync(tmpDir, { importFn });

      expect(registry.getAll()).toHaveLength(2);
      expect(registry.getAll().map((c) => c.name).sort()).toEqual(['exec', 'logs']);
    });

    it('discovers top-level commands from <name>/<name> pattern', async () => {
      tmpDir = await mkdtemp(join(tmpdir(), 'registry-'));
      await mkdir(join(tmpDir, 'serve'), { recursive: true });

      const serveCmd = makeCommand({ group: null, name: 'serve', scope: 'standalone' });

      const importFn = vi.fn().mockImplementation(async (path: string) => {
        if (path.includes(join('serve', 'serve.'))) {
          return { command: serveCmd };
        }
        throw new Error('Not found');
      });

      const registry = await CommandRegistry.discoverAsync(tmpDir, { importFn });

      expect(registry.getAll()).toHaveLength(1);
      expect(registry.getAll()[0].name).toBe('serve');
    });

    it('skips the framework directory', async () => {
      tmpDir = await mkdtemp(join(tmpdir(), 'registry-'));
      await mkdir(join(tmpDir, 'framework', 'framework'), { recursive: true });

      const importFn = vi.fn().mockResolvedValue({
        command: makeCommand({ name: 'should-not-find' }),
      });

      const registry = await CommandRegistry.discoverAsync(tmpDir, { importFn });

      expect(registry.getAll()).toEqual([]);
      expect(importFn).not.toHaveBeenCalled();
    });

    it('ignores non-command exports', async () => {
      tmpDir = await mkdtemp(join(tmpdir(), 'registry-'));
      await mkdir(join(tmpDir, 'utils', 'utils'), { recursive: true });

      const importFn = vi.fn().mockResolvedValue({
        helperFn: () => {},
        someConstant: 42,
        plainObject: { group: 'fake', name: 'fake' },
      });

      const registry = await CommandRegistry.discoverAsync(tmpDir, { importFn });

      expect(registry.getAll()).toEqual([]);
    });

    it('handles missing base directory gracefully', async () => {
      const registry = await CommandRegistry.discoverAsync('/nonexistent/path');

      expect(registry.getAll()).toEqual([]);
    });

    it('handles import errors gracefully', async () => {
      tmpDir = await mkdtemp(join(tmpdir(), 'registry-'));
      await mkdir(join(tmpDir, 'broken', 'broken'), { recursive: true });

      const importFn = vi.fn().mockRejectedValue(new Error('Syntax error'));

      const registry = await CommandRegistry.discoverAsync(tmpDir, { importFn });

      expect(registry.getAll()).toEqual([]);
    });

    it('collects multiple exports from a single module', async () => {
      tmpDir = await mkdtemp(join(tmpdir(), 'registry-'));
      // Only create the top-level dir (no nested subdir) so scanner
      // imports the module exactly once via the <name>/<name>.js pattern.
      await mkdir(join(tmpDir, 'bundle'), { recursive: true });

      const cmd1 = makeCommand({ group: 'bundle', name: 'alpha' });
      const cmd2 = makeCommand({ group: 'bundle', name: 'beta' });

      const importFn = vi.fn().mockResolvedValue({
        alphaCommand: cmd1,
        betaCommand: cmd2,
      });

      const registry = await CommandRegistry.discoverAsync(tmpDir, { importFn });

      expect(registry.getAll()).toHaveLength(2);
    });
  });
});
