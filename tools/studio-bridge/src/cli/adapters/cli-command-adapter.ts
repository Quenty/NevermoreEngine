/**
 * CLI adapter — converts a `CommandDefinition` into a yargs `CommandModule`.
 *
 * Responsibilities:
 *   - Maps `ArgDefinition` records to yargs positionals/options
 *   - Injects universal args based on scope and safety
 *   - Wraps handler in connect → resolve → fn → disconnect lifecycle
 *   - Calls `cli.formatResult` or falls back to JSON
 *   - Implements --output (file write), --open, --watch, --interval
 */

import * as fs from 'fs';
import { execSync } from 'child_process';
import type { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { createWatchRenderer } from '@quenty/cli-output-helpers/output-modes';
import { BridgeConnection } from '../../bridge/index.js';
import type { SessionContext } from '../../bridge/index.js';
import type { CommandDefinition } from '../../commands/framework/define-command.js';
import { toYargsOptions } from '../../commands/framework/arg-builder.js';
import { formatAsJson, resolveMode } from '../format-output.js';
import type { OutputMode } from '../format-output.js';

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
// Helpers
// ---------------------------------------------------------------------------

/** Extract only command-specific args from the full argv object. */
function extractCommandArgs(
  argv: Record<string, unknown>,
  def: CommandDefinition,
): Record<string, unknown> {
  const commandArgs: Record<string, unknown> = {};
  for (const name of Object.keys(def.args)) {
    if (name in argv) {
      commandArgs[name] = argv[name];
    }
  }
  return commandArgs;
}

/** Execute a command's handler with appropriate connection lifecycle. */
async function executeCommandAsync(
  def: CommandDefinition,
  commandArgs: Record<string, unknown>,
  argv: Record<string, unknown>,
  connect: CliLifecycleProvider['connectAsync'],
  existingConnection?: BridgeConnection,
): Promise<unknown> {
  if (def.scope === 'standalone') {
    return (def.handler as any)(commandArgs);
  }

  // Reuse existing connection if provided (watch mode), otherwise connect fresh
  const connection = existingConnection ?? await connect({
    timeoutMs: argv.timeout as number | undefined,
    remoteHost: argv.remote as string | undefined,
    local: argv.local as boolean | undefined,
    waitForSessions: def.scope === 'connection',
  });

  try {
    if (def.scope === 'session') {
      const session = await connection.resolveSessionAsync(
        argv.target as string | undefined,
        argv.context as SessionContext | undefined,
      );
      return (def.handler as any)(session, commandArgs);
    }
    return (def.handler as any)(connection, commandArgs);
  } finally {
    // Only disconnect if we created the connection
    if (!existingConnection) {
      await connection.disconnectAsync();
    }
  }
}

/** Format the command result for the given output mode. */
function formatForOutput(
  def: CommandDefinition,
  result: unknown,
  mode: OutputMode,
  explicitFormat: string | undefined,
): string {
  const formatters = def.cli?.formatResult;

  // Check command-specific formatter first
  if (formatters?.[mode]) {
    return formatters[mode]!(result as any);
  }

  // Built-in defaults
  if (mode === 'json') {
    return formatAsJson(result);
  }

  // For text/table: try summary fallback, then JSON
  if (typeof result === 'object' && result !== null && 'summary' in result) {
    return (result as any).summary;
  }

  // If user explicitly asked for a format we can't handle, error
  if (explicitFormat && explicitFormat !== 'json') {
    throw new Error(
      `Command '${def.name}' does not support --format ${explicitFormat}`,
    );
  }

  return formatAsJson(result);
}

/** Write result to stdout or a file. */
function outputResult(
  def: CommandDefinition,
  result: unknown,
  mode: OutputMode,
  argv: Record<string, unknown>,
): void {
  const outputPath = argv.output as string | undefined;
  const formatted = formatForOutput(def, result, mode, argv.format as string | undefined);

  if (outputPath) {
    const binaryField = def.cli?.binaryField;
    // Write raw binary when binaryField is set and format is not json
    if (binaryField && argv.format !== 'json' && typeof result === 'object' && result !== null) {
      const base64Data = (result as Record<string, unknown>)[binaryField];
      if (typeof base64Data === 'string') {
        fs.writeFileSync(outputPath, Buffer.from(base64Data, 'base64'));
        process.stderr.write(`Wrote binary output to ${outputPath}\n`);
      } else {
        fs.writeFileSync(outputPath, formatted, 'utf-8');
        process.stderr.write(`Wrote output to ${outputPath}\n`);
      }
    } else {
      fs.writeFileSync(outputPath, formatted, 'utf-8');
      process.stderr.write(`Wrote output to ${outputPath}\n`);
    }

    if (argv.open) {
      tryOpenFile(outputPath);
    }
  } else {
    console.log(formatted);
  }
}

/** Best-effort open a file with the platform's default viewer. */
function tryOpenFile(filePath: string): void {
  try {
    const cmd =
      process.platform === 'darwin' ? 'open' :
      process.platform === 'win32' ? 'start ""' :
      'xdg-open';
    execSync(`${cmd} ${JSON.stringify(filePath)}`, { stdio: 'ignore' });
  } catch {
    // Fire-and-forget — don't fail the command if open doesn't work
  }
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
      const commandArgs = extractCommandArgs(argv, def);
      const outputMode = resolveMode({ format: argv.format });
      const connect =
        options?.lifecycle?.connectAsync.bind(options.lifecycle) ??
        BridgeConnection.connectAsync.bind(BridgeConnection);

      try {
        if (argv.watch && def.safety === 'read') {
          await runWatchModeAsync(def, commandArgs, argv, outputMode, connect);
        } else {
          await runOnceAsync(def, commandArgs, argv, outputMode, connect);
        }
      } catch (err) {
        OutputHelper.error(err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    },
  };
}

// ---------------------------------------------------------------------------
// Run modes
// ---------------------------------------------------------------------------

/** Execute once, format, output, and exit. */
async function runOnceAsync(
  def: CommandDefinition,
  commandArgs: Record<string, unknown>,
  argv: Record<string, unknown>,
  outputMode: OutputMode,
  connect: CliLifecycleProvider['connectAsync'],
): Promise<void> {
  const result = await executeCommandAsync(def, commandArgs, argv, connect);
  outputResult(def, result, outputMode, argv);
}

/** Open a connection, poll the command, and render updates. */
async function runWatchModeAsync(
  def: CommandDefinition,
  commandArgs: Record<string, unknown>,
  argv: Record<string, unknown>,
  outputMode: OutputMode,
  connect: CliLifecycleProvider['connectAsync'],
): Promise<void> {
  const intervalMs = (argv.interval as number | undefined) ?? 1000;

  // For standalone commands, no persistent connection
  if (def.scope === 'standalone') {
    await runWatchPollAsync(def, commandArgs, argv, outputMode, connect, intervalMs);
    return;
  }

  // Open connection once and reuse across polls
  const connection = await connect({
    timeoutMs: argv.timeout as number | undefined,
    remoteHost: argv.remote as string | undefined,
    local: argv.local as boolean | undefined,
    waitForSessions: def.scope === 'connection',
  });

  try {
    await runWatchPollAsync(def, commandArgs, argv, outputMode, connect, intervalMs, connection);
  } finally {
    await connection.disconnectAsync();
  }
}

/** Inner poll loop shared by watch mode. */
async function runWatchPollAsync(
  def: CommandDefinition,
  commandArgs: Record<string, unknown>,
  argv: Record<string, unknown>,
  outputMode: OutputMode,
  connect: CliLifecycleProvider['connectAsync'],
  intervalMs: number,
  connection?: BridgeConnection,
): Promise<void> {
  let lastResult: unknown;
  let stopped = false;

  // Fetch initial result
  lastResult = await executeCommandAsync(def, commandArgs, argv, connect, connection);

  const outputPath = argv.output as string | undefined;

  if (outputPath) {
    // File-write poll loop: overwrite on each tick, status to stderr
    outputResult(def, lastResult, outputMode, argv);

    const poll = async (): Promise<void> => {
      while (!stopped) {
        await new Promise((resolve) => setTimeout(resolve, intervalMs));
        if (stopped) break;
        lastResult = await executeCommandAsync(def, commandArgs, argv, connect, connection);
        outputResult(def, lastResult, outputMode, argv);
      }
    };

    const cleanup = (): void => {
      stopped = true;
    };
    process.on('SIGINT', cleanup);
    process.on('SIGTERM', cleanup);

    await poll();
  } else {
    // TTY watch mode: use live-rewriting renderer
    const renderer = createWatchRenderer(
      () => formatForOutput(def, lastResult, outputMode, argv.format as string | undefined),
      { intervalMs },
    );

    const cleanup = (): void => {
      stopped = true;
      renderer.stop();
    };
    process.on('SIGINT', cleanup);
    process.on('SIGTERM', cleanup);

    renderer.start();

    while (!stopped) {
      await new Promise((resolve) => setTimeout(resolve, intervalMs));
      if (stopped) break;
      try {
        lastResult = await executeCommandAsync(def, commandArgs, argv, connect, connection);
        renderer.update();
      } catch {
        // Swallow transient errors during polling
      }
    }
  }
}
