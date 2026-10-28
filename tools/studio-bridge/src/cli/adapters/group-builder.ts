/**
 * Group builder — converts a `CommandRegistry` into yargs `CommandModule`
 * entries with grouped subcommands.
 *
 * Grouped commands become parent commands with subcommands:
 *   `console exec <code>`  →  `console` parent, `exec` subcommand
 *
 * A group name with a space nests under its first word:
 *   `playtest player list`  →  `player` subcommand group of `playtest`
 *
 * Top-level commands (group = null) are returned as standalone modules:
 *   `serve`, `mcp`, `terminal`
 */

import type { CommandModule } from 'yargs';
import type { CommandRegistry } from '../../commands/framework/command-registry.js';
import type { CliLifecycleProvider } from './cli-command-adapter.js';
import { buildYargsCommand } from './cli-command-adapter.js';

const GROUP_DESCRIPTIONS: Record<string, string> = {
  console: 'Execute code and view logs',
  explorer: 'Query and modify the DataModel',
  properties: 'Read and write instance properties',
  viewport: 'Screenshots and camera control',
  data: 'Load and save serialized data',
  playtest: 'Control play test sessions',
  'playtest player': 'List, add and remove the players of a multiplayer test',
  process: 'Open and manage Studio',
  plugin: 'Manage the bridge plugin',
  action: 'Invoke a Studio action',
  linux: 'Linux/Wine environment management',
};

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
  options: GroupBuilderOptions = {}
): GroupBuilderResult {
  const groups: CommandModule[] = [];
  const topLevel: CommandModule[] = [];

  const allGroups = registry.getGroups();
  const topGroups = [...new Set(allGroups.map((name) => name.split(' ')[0]))];

  // Grouped commands → parent module with subcommands
  for (const groupName of topGroups) {
    groups.push(buildGroupModule(registry, allGroups, groupName, options));
  }

  // Top-level commands (group = null) → standalone modules
  for (const cmd of registry.getTopLevel()) {
    topLevel.push(buildYargsCommand(cmd, options));
  }

  return { groups, topLevel };
}

function buildGroupModule(
  registry: CommandRegistry,
  allGroups: string[],
  groupName: string,
  options: GroupBuilderOptions
): CommandModule {
  const commands = registry.getByGroup(groupName);
  const subgroups = allGroups.filter(
    (name) =>
      name.startsWith(`${groupName} `) &&
      !name.slice(groupName.length + 1).includes(' ')
  );
  // Naming the subcommands lets a reader find e.g. `process launch` from the top-level help
  const names = [
    ...commands.map((cmd) => cmd.name),
    ...subgroups.map((subgroup) => subgroup.split(' ').pop()),
  ];
  const description = `${
    GROUP_DESCRIPTIONS[groupName] ?? `${groupName} commands`
  }: ${names.join(', ')}`;

  return {
    command: `${groupName.split(' ').pop()} <command>`,
    describe: description,
    builder: (yargs) => {
      for (const cmd of commands) {
        yargs.command(buildYargsCommand(cmd, options) as any);
      }
      for (const subgroup of subgroups) {
        yargs.command(
          buildGroupModule(registry, allGroups, subgroup, options) as any
        );
      }
      return yargs.demandCommand(
        1,
        `Run 'studio-bridge ${groupName} --help' for available commands`
      );
    },
    handler: () => {},
  };
}
