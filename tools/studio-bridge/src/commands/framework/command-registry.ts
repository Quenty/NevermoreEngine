/**
 * Command registry — collects `CommandDefinition` objects and provides
 * lookup by group, name, category, and scope. Supports convention-based
 * discovery via `discoverAsync()` which scans a directory tree and
 * dynamically imports modules to find branded exports.
 */

import { readdir } from 'fs/promises';
import { join } from 'path';
import { pathToFileURL } from 'url';
import {
  isCommandDefinition,
  type CommandDefinition,
  type CommandCategory,
} from './define-command.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface DiscoverOptions {
  /**
   * Override the dynamic import function. Receives the absolute file path
   * and should return the module's exports. Useful for testing without
   * real JS files on disk.
   */
  importFn?: (filePath: string) => Promise<Record<string, unknown>>;
}

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

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

  // -----------------------------------------------------------------------
  // Convention-based discovery
  // -----------------------------------------------------------------------

  /**
   * Scan `baseDir` for command modules following the naming convention:
   *
   *   - `<name>/<name>.js`              — top-level commands
   *   - `<group>/<name>/<name>.js`      — grouped commands
   *
   * Each module is dynamically imported and all exports bearing the
   * `COMMAND_BRAND` symbol are registered.
   *
   * The `framework/` subdirectory is always skipped.
   */
  static async discoverAsync(
    baseDir: string,
    options: DiscoverOptions = {},
  ): Promise<CommandRegistry> {
    const doImport =
      options.importFn ??
      ((filePath: string) => import(pathToFileURL(filePath).href));

    const registry = new CommandRegistry();

    let topEntries;
    try {
      topEntries = await readdir(baseDir, { withFileTypes: true });
    } catch {
      return registry;
    }

    for (const topEntry of topEntries) {
      if (!topEntry.isDirectory() || topEntry.name === 'framework') continue;

      const topDir = join(baseDir, topEntry.name);

      // Try <name>/<name>.js (top-level or single-command directory)
      await CommandRegistry._tryImportAsync(
        registry,
        join(topDir, `${topEntry.name}.js`),
        doImport,
      );

      // Try <group>/<name>/<name>.js (grouped commands)
      let subEntries;
      try {
        subEntries = await readdir(topDir, { withFileTypes: true });
      } catch {
        continue;
      }

      for (const subEntry of subEntries) {
        if (!subEntry.isDirectory()) continue;

        await CommandRegistry._tryImportAsync(
          registry,
          join(topDir, subEntry.name, `${subEntry.name}.js`),
          doImport,
        );
      }
    }

    return registry;
  }

  // -----------------------------------------------------------------------
  // Internals
  // -----------------------------------------------------------------------

  private static async _tryImportAsync(
    registry: CommandRegistry,
    filePath: string,
    importFn: (path: string) => Promise<Record<string, unknown>>,
  ): Promise<void> {
    let mod: Record<string, unknown>;
    try {
      mod = await importFn(filePath);
    } catch {
      return;
    }

    for (const value of Object.values(mod)) {
      if (isCommandDefinition(value)) {
        registry.register(value);
      }
    }
  }
}
