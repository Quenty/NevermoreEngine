/**
 * Terminal adapter — generates dot-command entries and a dispatch function
 * from a `CommandRegistry`. Replaces the hand-coded switch statement in
 * `TerminalDotCommands` with registry-driven dispatch.
 *
 * Dot-command names use the format `.{name}` (e.g. `.state`, `.logs`).
 * Standalone commands (serve, mcp) are excluded since they don't make
 * sense in an interactive terminal session.
 */

import type { BridgeConnection } from '../../../bridge/index.js';
import type { BridgeSession } from '../../../bridge/index.js';
import type { CommandRegistry } from '../../../commands/framework/command-registry.js';
import type { CommandDefinition } from '../../../commands/framework/define-command.js';
import type { DotCommandEntry, DotCommandResult } from './terminal-dot-commands.js';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

export interface TerminalCommandAdapter {
  /** Dot-command entries for help display. */
  entries: DotCommandEntry[];
  /**
   * Dispatch a dot-command string. Returns `{ handled: false }` if the
   * command is not recognized.
   */
  dispatchAsync(
    input: string,
    connection: BridgeConnection | undefined,
    session: BridgeSession | undefined,
  ): Promise<DotCommandResult>;
}

/**
 * Build a terminal command adapter from the registry. Maps each
 * session/connection command to a `.{name}` dot-command.
 */
export function buildTerminalCommands(
  registry: CommandRegistry,
): TerminalCommandAdapter {
  const entries: DotCommandEntry[] = [];
  const commandMap = new Map<string, CommandDefinition>();

  for (const def of registry.getAll()) {
    // Skip standalone commands (serve, mcp, terminal itself)
    if (def.scope === 'standalone') continue;

    const dotName = `.${def.name}`;

    // Build usage string with positional args
    const positionalNames = Object.entries(def.args)
      .filter(([, a]) => a.kind === 'positional')
      .map(([name]) => `<${name}>`)
      .join(' ');

    entries.push({
      name: dotName,
      description: def.description,
      usage: positionalNames ? `${dotName} ${positionalNames}` : undefined,
    });

    commandMap.set(dotName, def);
  }

  return {
    entries,
    dispatchAsync: async (
      input: string,
      connection: BridgeConnection | undefined,
      session: BridgeSession | undefined,
    ): Promise<DotCommandResult> => {
      const parts = input.trim().split(/\s+/);
      const cmd = parts[0].toLowerCase();

      const def = commandMap.get(cmd);
      if (!def) {
        return { handled: false };
      }

      // Parse simple args from remaining text
      const argText = parts.slice(1).join(' ').trim();
      const commandArgs: Record<string, unknown> = {};

      // For commands with a single positional arg, pass remaining text
      const positionalArgs = Object.entries(def.args).filter(
        ([, a]) => a.kind === 'positional',
      );
      if (positionalArgs.length === 1 && argText) {
        commandArgs[positionalArgs[0][0]] = argText;
      }

      try {
        let result: unknown;

        if (def.scope === 'session') {
          if (!session) {
            return {
              handled: true,
              error:
                'No active session. Use .connect <id> or .sessions to see available sessions.',
            };
          }
          result = await (def.handler as any)(session, commandArgs);
        } else if (def.scope === 'connection') {
          if (!connection) {
            return {
              handled: true,
              error: 'No bridge connection available.',
            };
          }
          result = await (def.handler as any)(connection, commandArgs);
        } else {
          result = await (def.handler as any)(commandArgs);
        }

        // Use the summary field if available, otherwise JSON
        const summary = (result as any)?.summary;
        return {
          handled: true,
          output: summary ?? JSON.stringify(result),
        };
      } catch (err) {
        return {
          handled: true,
          error: err instanceof Error ? err.message : String(err),
        };
      }
    },
  };
}
