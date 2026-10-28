/**
 * CLI adapter — converts a `CommandDefinition` into a yargs `CommandModule`.
 *
 * Responsibilities:
 *   - Maps `ArgDefinition` records to yargs positionals/options
 *   - Injects universal args based on scope and safety
 *   - Wraps handler in connect → resolve → fn → disconnect lifecycle
 *   - Dispatches results to a `ResultReporter` (stdout / file / watch redraw)
 *   - Honors `--output` (file write), `--open`, `--watch`, `--interval`
 */

import type { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  buildResultReporter,
  type ResultReporter,
  formatJson,
} from '@quenty/cli-output-helpers/reporting';
import { BridgeConnection } from '../../bridge/index.js';
import type { BridgeSession, SessionContext } from '../../bridge/index.js';
import type {
  CommandDefinition,
  SessionTargeting,
} from '../../commands/framework/define-command.js';
import { toYargsOptions } from '../../commands/framework/arg-builder.js';
import { explainMissingPlaytestContextAsync } from '../../commands/playtest/playtest-sessions.js';
import {
  addWarning,
  getWarnings,
  warnIfPluginStaleAsync,
} from '../cli-output-context.js';

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

/** Extract only command-specific args from the full argv object. */
function extractCommandArgs(
  argv: Record<string, unknown>,
  def: CommandDefinition
): Record<string, unknown> {
  const commandArgs: Record<string, unknown> = {};
  for (const [name, argDef] of Object.entries(def.args)) {
    if (argDef.kind === 'passthrough') {
      commandArgs[name] = ((argv['--'] as unknown[] | undefined) ?? []).map(
        String
      );
    } else if (name in argv) {
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
  existingConnection?: BridgeConnection
): Promise<unknown> {
  if (def.scope === 'standalone') {
    return (def.handler as any)(commandArgs);
  }

  // Reuse existing connection if provided (watch mode), otherwise connect fresh
  const connection =
    existingConnection ??
    (await connect({
      timeoutMs: argv.timeout as number | undefined,
      remoteHost: argv.remote as string | undefined,
      local: argv.local as boolean | undefined,
      waitForSessions: def.scope === 'connection',
    }));

  const targeting: SessionTargeting = {
    target: argv.target as string | undefined,
    context: argv.context as SessionContext | undefined,
  };

  if (connection.isHostOutdated) {
    addWarning(
      `The bridge host on port ${connection.port} runs an older studio-bridge, which may drop newer options. Restart it (e.g. stop 'studio-bridge serve') to use this version.`
    );
  }

  try {
    if (def.scope === 'session') {
      const session = await connection
        .resolveSessionAsync(targeting.target, targeting.context)
        .catch(async (err: unknown) => {
          throw await explainMissingPlaytestContextAsync(connection, err);
        });
      if (def.changesDataModel && !argv.allowEdit) {
        assertNotEditingDuringPlaytest(connection, session);
      }
      await warnIfPluginStaleAsync([session.info]);
      return await (def.handler as any)(session, commandArgs, connection);
    }
    await warnIfPluginStaleAsync(connection.listSessions());
    return await (def.handler as any)(connection, commandArgs, targeting);
  } finally {
    if (!existingConnection) {
      await connection.disconnectAsync();
    }
  }
}

/**
 * Refuses to change an edit DataModel while a playtest of it runs: the
 * playtest runs a copy, so the change would not show up there.
 */
export function assertNotEditingDuringPlaytest(
  connection: BridgeConnection,
  session: BridgeSession
): void {
  if (session.context !== 'edit') return;

  const playtest = connection
    .listSessions()
    .find(
      (s) => s.instanceId === session.info.instanceId && s.context === 'server'
    );
  if (playtest) {
    throw new Error(
      `A playtest of '${session.info.placeName}' is running, so this would change Edit, not the playtest. Target the playtest with --context server (or client), or pass --allow-edit to change Edit anyway.`
    );
  }
}

/** Inject version/diagnostic warnings into JSON result objects. */
function injectWarnings(result: unknown): unknown {
  const warnings = getWarnings();
  if (warnings.length === 0) return result;
  if (typeof result === 'object' && result !== null && !Array.isArray(result)) {
    return { ...result, _warnings: warnings };
  }
  return result;
}

/**
 * Render a command result for stdout/file output. `--format=json` (or any
 * explicit non-text format) routes through the command's `json` override or
 * falls back to `formatJson`. Anything else (default, `--format=text`)
 * routes through the command's `format` callback, then `result.summary`,
 * then JSON as a last resort.
 */
function renderResult(
  def: CommandDefinition,
  result: unknown,
  explicitFormat: string | undefined
): string {
  if (explicitFormat === 'json') {
    if (def.cli?.json) return def.cli.json(result as any);
    return formatJson(injectWarnings(result), { pretty: process.stdout.isTTY });
  }

  if (def.cli?.format) return def.cli.format(result as any);

  if (typeof result === 'object' && result !== null && 'summary' in result) {
    return (result as any).summary;
  }

  return formatJson(result);
}

/**
 * Extract a Buffer from the result's binary field, or undefined if no
 * binary field is configured / extractable / requested. When `--format=json`
 * is explicit the user wants JSON not raw bytes — return undefined so the
 * file reporter falls back to text rendering.
 */
function extractBinaryBuffer(
  def: CommandDefinition,
  result: unknown,
  format: string | undefined
): Buffer | undefined {
  if (format === 'json') return undefined;
  const binaryField = def.cli?.binaryField;
  if (!binaryField) return undefined;
  if (typeof result !== 'object' || result === null) return undefined;
  const data = (result as Record<string, unknown>)[binaryField];
  if (typeof data !== 'string') return undefined;
  return Buffer.from(data, 'base64');
}

export function buildYargsCommand(
  def: CommandDefinition,
  options?: { lifecycle?: CliLifecycleProvider }
): CommandModule {
  const { positionals, options: yargsOptions } = toYargsOptions(def.args);

  const positionalSuffix = positionals
    .map((p) => {
      const name = p.options.array ? `${p.name}..` : p.name;
      return p.options.demandOption ? `<${name}>` : `[${name}]`;
    })
    .join(' ');

  const command = positionalSuffix
    ? `${def.name} ${positionalSuffix}`
    : def.name;

  return {
    command,
    describe: def.description,
    builder: (yargs: Argv) => {
      for (const pos of positionals) {
        yargs.positional(pos.name, pos.options as any);
      }

      for (const argDef of Object.values(def.args)) {
        if (argDef.kind === 'passthrough') {
          yargs.epilogue(`-- <args..>  ${argDef.description}`);
        }
      }

      for (const [name, opt] of Object.entries(yargsOptions)) {
        yargs.option(name, opt as any);
      }

      if (def.scope === 'session' || def.scope === 'connection') {
        yargs.option('target', {
          alias: 't',
          type: 'string',
          describe: 'Target session or instance ID',
        });
        yargs.option('context', {
          type: 'string',
          describe: 'Target context (edit, client, server)',
          choices: ['edit', 'client', 'server'],
        });
      }

      if (def.changesDataModel && def.scope === 'session') {
        yargs.option('allow-edit', {
          type: 'boolean',
          default: false,
          describe: 'Allow changing Edit while a playtest of it runs',
        });
      }

      yargs.option('format', {
        type: 'string',
        choices: ['text', 'json'],
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
      const explicitFormat = argv.format as string | undefined;
      const reporter = buildResultReporter<unknown>({
        outputPath: argv.output as string | undefined,
        watch: !!argv.watch && def.safety === 'read',
        open: argv.open as boolean | undefined,
        intervalMs: argv.interval as number | undefined,
        render: (result) => renderResult(def, result, explicitFormat),
        binary: (result) => extractBinaryBuffer(def, result, explicitFormat),
      });
      const connect =
        options?.lifecycle?.connectAsync.bind(options.lifecycle) ??
        BridgeConnection.connectAsync.bind(BridgeConnection);

      try {
        if (argv.watch && def.safety === 'read') {
          await runWatchModeAsync(def, commandArgs, argv, reporter, connect);
        } else {
          await runOnceAsync(def, commandArgs, argv, reporter, connect);
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        if (explicitFormat === 'json') {
          console.log(
            formatJson(injectWarnings({ success: false, error: message }), {
              pretty: process.stdout.isTTY,
            })
          );
        } else {
          OutputHelper.error(message);
        }
        process.exit(1);
      }
    },
  };
}

async function runOnceAsync(
  def: CommandDefinition,
  commandArgs: Record<string, unknown>,
  argv: Record<string, unknown>,
  reporter: ResultReporter<unknown>,
  connect: CliLifecycleProvider['connectAsync']
): Promise<void> {
  const result = await executeCommandAsync(def, commandArgs, argv, connect);

  await reporter.startAsync();
  reporter.onResult(result);
  await reporter.stopAsync();

  if (
    typeof result === 'object' &&
    result !== null &&
    'success' in result &&
    !(result as any).success
  ) {
    process.exit(1);
  }
}

async function runWatchModeAsync(
  def: CommandDefinition,
  commandArgs: Record<string, unknown>,
  argv: Record<string, unknown>,
  reporter: ResultReporter<unknown>,
  connect: CliLifecycleProvider['connectAsync']
): Promise<void> {
  const intervalMs = (argv.interval as number | undefined) ?? 1000;

  // Standalone commands run without a persistent connection
  const connection: BridgeConnection | undefined =
    def.scope === 'standalone'
      ? undefined
      : await connect({
          timeoutMs: argv.timeout as number | undefined,
          remoteHost: argv.remote as string | undefined,
          local: argv.local as boolean | undefined,
          waitForSessions: def.scope === 'connection',
        });

  let stopped = false;
  const cleanup = (): void => {
    stopped = true;
  };
  process.on('SIGINT', cleanup);
  process.on('SIGTERM', cleanup);

  try {
    await reporter.startAsync();

    let result = await executeCommandAsync(
      def,
      commandArgs,
      argv,
      connect,
      connection
    );
    reporter.onResult(result);

    while (!stopped) {
      await new Promise((resolve) => setTimeout(resolve, intervalMs));
      if (stopped) break;
      try {
        result = await executeCommandAsync(
          def,
          commandArgs,
          argv,
          connect,
          connection
        );
        reporter.onResult(result);
      } catch {
        // Swallow transient errors during polling
      }
    }
  } finally {
    await reporter.stopAsync();
    if (connection) {
      await connection.disconnectAsync();
    }
  }
}
