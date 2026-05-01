/**
 * Command registry — collects `CommandDefinition` objects and provides
 * lookup by group, name, category, and scope.
 */

import type { CommandDefinition, CommandCategory } from './define-command.js';

export class CommandRegistry {
  private _commands: CommandDefinition[] = [];

  /** Register a command definition. */
  register(def: CommandDefinition): void {
    this._commands.push(def);
  }

  /** Return all registered commands in insertion order. */
  getAll(): readonly CommandDefinition[] {
    return this._commands;
  }

  /** Return commands belonging to a specific group. */
  getByGroup(group: string): readonly CommandDefinition[] {
    return this._commands.filter((d) => d.group === group);
  }

  /** Return unique group names (excluding top-level commands). */
  getGroups(): string[] {
    const groups = new Set<string>();
    for (const cmd of this._commands) {
      if (cmd.group !== null) {
        groups.add(cmd.group);
      }
    }
    return [...groups];
  }

  /** Return top-level commands (group is `null`). */
  getTopLevel(): readonly CommandDefinition[] {
    return this._commands.filter((d) => d.group === null);
  }

  /** Return commands in a given category. */
  getByCategory(category: CommandCategory): readonly CommandDefinition[] {
    return this._commands.filter((d) => d.category === category);
  }

  /** Find a specific command by group and name. */
  get(group: string | null, name: string): CommandDefinition | undefined {
    return this._commands.find((d) => d.group === group && d.name === name);
  }
}
