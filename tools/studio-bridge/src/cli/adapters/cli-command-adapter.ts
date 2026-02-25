/**
 * CLI adapter — converts a `CommandDefinition` into a yargs `CommandModule`.
 *
 * Responsibilities:
 *   - Maps `ArgDefinition` records to yargs positionals/options
 *   - Injects universal args based on scope and safety
 *   - Wraps handler in connect → resolve → fn → disconnect lifecycle
 *   - Calls `cli.formatResult` or falls back to JSON
 */

import type { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { BridgeConnection } from '../../bridge/index.js';
import type { SessionContext } from '../../bridge/index.js';
import type { CommandDefinition } from '../../commands/framework/define-command.js';
import { toYargsOptions } from '../../commands/framework/arg-builder.js';
import { formatAsJson, resolveMode } from '../format-output.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Args injected by the adapter (not defined on CommandDefinition). */
export interface AdapterArgs {
  target?: string;
  context?: string;
  format?: string;
  output?: string;
  open?: boolean;
  watch?: boolean;
  interval?: number;
}

/**
 * Optional lifecycle override for testing. When provided, the adapter
 * calls these instead of `BridgeConnection.connectAsync`.
 */
export interface CliLifecycleProvider {
  connectAsync(opts: {
    timeoutMs?: number;
    remoteHost?: string;
    local?: boolean;
    waitForSessions?: boolean;
  }): Promise<BridgeConnection>;
}

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

/**
 * Build a yargs `CommandModule` from a `CommandDefinition`.
 *
 * @param def     The command definition
 * @param options Optional overrides (lifecycle provider for testing)
 */
export function buildYargsCommand(
  def: CommandDefinition,
  options?: { lifecycle?: CliLifecycleProvider },
): CommandModule {
  const { positionals, options: yargsOptions } = toYargsOptions(def.args);

  // Build command string: "exec <code>" or "list"
  const positionalSuffix = positionals
    .map((p) => (p.options.demandOption ? `<${p.name}>` : `[${p.name}]`))
    .join(' ');

  const command = positionalSuffix
    ? `${def.name} ${positionalSuffix}`
    : def.name;

  return {
    command,
    describe: def.description,
    builder: (yargs: Argv) => {
      // Register positional args
      for (const pos of positionals) {
        yargs.positional(pos.name, pos.options as any);
      }

      // Register command-specific options
      for (const [name, opt] of Object.entries(yargsOptions)) {
        yargs.option(name, opt as any);
      }

      // Inject targeting for session/connection-scoped commands
      if (def.scope === 'session' || def.scope === 'connection') {
        yargs.option('target', {
          alias: 't',
          type: 'string',
          describe: 'Target session ID (or "all" for broadcast)',
        });
        yargs.option('context', {
          type: 'string',
          describe: 'Target context (edit, client, server)',
          choices: ['edit', 'client', 'server'],
        });
      }

      // Universal output options
      yargs.option('format', {
        type: 'string',
        choices: ['text', 'json', 'base64'],
        describe: 'Output format',
      });
      yargs.option('output', {
        alias: 'o',
        type: 'string',
        describe: 'Write output to file',
      });
      yargs.option('open', {
        type: 'boolean',
        default: false,
        describe: 'Open output file after writing',
      });

      // Watch mode for read-safety commands
      if (def.safety === 'read') {
        yargs.option('watch', {
          alias: 'w',
          type: 'boolean',
          default: false,
          describe: 'Watch for changes',
        });
        yargs.option('interval', {
          type: 'number',
          default: 1000,
          describe: 'Watch interval in milliseconds',
        });
      }

      return yargs;
    },
    handler: async (argv: any) => {
      // Extract only command-specific args
      const commandArgs: Record<string, unknown> = {};
      for (const name of Object.keys(def.args)) {
        if (name in argv) {
          commandArgs[name] = argv[name];
        }
      }

      const outputMode = resolveMode({ json: argv.format === 'json' });
      const connect =
        options?.lifecycle?.connectAsync.bind(options.lifecycle) ??
        BridgeConnection.connectAsync.bind(BridgeConnection);

      try {
        let result: unknown;

        if (def.scope === 'standalone') {
          result = await (def.handler as any)(commandArgs);
        } else {
          let connection: BridgeConnection | undefined;
          try {
            connection = await connect({
              timeoutMs: argv.timeout,
              remoteHost: argv.remote,
              local: argv.local,
              waitForSessions: def.scope === 'connection',
            });

            if (def.scope === 'session') {
              const session = await connection.resolveSessionAsync(
                argv.target,
                argv.context as SessionContext | undefined,
              );
              result = await (def.handler as any)(session, commandArgs);
            } else {
              result = await (def.handler as any)(connection, commandArgs);
            }
          } finally {
            if (connection) await connection.disconnectAsync();
          }
        }

        // Format and output
        if (def.cli?.formatResult) {
          console.log(def.cli.formatResult(result as any, outputMode));
        } else {
          console.log(formatAsJson(result));
        }
      } catch (err) {
        OutputHelper.error(err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    },
  };
}
