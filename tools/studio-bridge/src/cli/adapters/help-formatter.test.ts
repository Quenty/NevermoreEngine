/**
 * Unit tests for the help formatter.
 */

import { describe, it, expect } from 'vitest';
import { formatGroupedHelp } from './help-formatter.js';
import { CommandRegistry } from '../../commands/framework/command-registry.js';
import { defineCommand } from '../../commands/framework/define-command.js';

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
      description: 'Start the bridge server',
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

describe('formatGroupedHelp', () => {
  it('includes Execution header', () => {
    const help = formatGroupedHelp(makeRegistry());
    expect(help).toContain('Execution:');
  });

  it('includes Infrastructure header', () => {
    const help = formatGroupedHelp(makeRegistry());
    expect(help).toContain('Infrastructure:');
  });

  it('lists execution groups under Execution', () => {
    const help = formatGroupedHelp(makeRegistry());
    const executionSection = help.split('Infrastructure:')[0];
    expect(executionSection).toContain('console <command>');
  });

  it('lists infrastructure groups under Infrastructure', () => {
    const help = formatGroupedHelp(makeRegistry());
    const infraSection = help.split('Infrastructure:')[1];
    expect(infraSection).toContain('process <command>');
  });

  it('lists top-level infrastructure commands', () => {
    const help = formatGroupedHelp(makeRegistry());
    const infraSection = help.split('Infrastructure:')[1];
    expect(infraSection).toContain('serve');
    expect(infraSection).toContain('Start the bridge server');
  });

  it('includes group descriptions', () => {
    const help = formatGroupedHelp(makeRegistry());
    expect(help).toContain('Execute code and view logs');
    expect(help).toContain('Manage Studio processes');
  });

  it('returns empty for empty registry', () => {
    const help = formatGroupedHelp(new CommandRegistry());
    expect(help).toContain('studio-bridge <command>');
    expect(help).not.toContain('Execution:');
    expect(help).not.toContain('Infrastructure:');
  });
});
