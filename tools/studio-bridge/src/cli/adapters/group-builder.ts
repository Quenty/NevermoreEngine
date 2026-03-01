/**
 * Group builder — converts a `CommandRegistry` into yargs `CommandModule`
 * entries with grouped subcommands.
 *
 * Grouped commands become parent commands with subcommands:
 *   `console exec <code>`  →  `console` parent, `exec` subcommand
 *
 * Top-level commands (group = null) are returned as standalone modules:
 *   `serve`, `mcp`, `terminal`
 */

import type { CommandModule } from 'yargs';
import type { CommandRegistry } from '../../commands/framework/command-registry.js';
import type { CliLifecycleProvider } from './cli-command-adapter.js';
import { buildYargsCommand } from './cli-command-adapter.js';

// ---------------------------------------------------------------------------
// Group descriptions (shown in parent command help)
// ---------------------------------------------------------------------------

const GROUP_DESCRIPTIONS: Record<string, string> = {
  console: 'Execute code and view logs',
  explorer: 'Query and modify the DataModel',
  properties: 'Read and write instance properties',
  viewport: 'Screenshots and camera control',
  data: 'Load and save serialized data',
  playtest: 'Control play test sessions',
  process: 'Manage Studio processes',
  plugin: 'Manage the bridge plugin',
  action: 'Invoke a Studio action',
};

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

export interface GroupBuilderOptions {
  lifecycle?: CliLifecycleProvider;
}

export interface GroupBuilderResult {
  /** Parent commands for each group (e.g. `console <command>`). */
  groups: CommandModule[];
  /** Top-level commands with no group (e.g. `serve`, `mcp`). */
  topLevel: CommandModule[];
}

/**
 * Build yargs command modules from a registry. Returns grouped parent
 * commands and top-level standalone commands separately so the caller
 * can register them independently.
 */
export function buildGroupCommands(
  registry: CommandRegistry,
  options: GroupBuilderOptions = {},
): GroupBuilderResult {
  const groups: CommandModule[] = [];
  const topLevel: CommandModule[] = [];

  // Grouped commands → parent module with subcommands
  for (const groupName of registry.getGroups()) {
    const commands = registry.getByGroup(groupName);
    const description = GROUP_DESCRIPTIONS[groupName] ?? `${groupName} commands`;

    groups.push({
      command: `${groupName} <command>`,
      describe: description,
      builder: (yargs) => {
        for (const cmd of commands) {
          yargs.command(buildYargsCommand(cmd, options) as any);
        }
        return yargs.demandCommand(1, `Run 'studio-bridge ${groupName} --help' for available commands`);
      },
      handler: () => {},
    });
  }

  // Top-level commands (group = null) → standalone modules
  for (const cmd of registry.getTopLevel()) {
    topLevel.push(buildYargsCommand(cmd, options));
  }

  return { groups, topLevel };
}
