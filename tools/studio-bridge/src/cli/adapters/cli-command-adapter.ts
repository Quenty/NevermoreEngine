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

import * as fs from 'fs';
import * as path from 'path';
import type { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  buildResultReporter,
  type ResultReporter,
  formatCsv,
  formatJson,
} from '@quenty/cli-output-helpers/reporting';
import {
  BridgeConnection,
  SessionNotFoundError,
  shouldAutoStartHost,
} from '../../bridge/index.js';
import type { BridgeSession, SessionContext } from '../../bridge/index.js';
import type {
  CliWatchConfig,
  CommandDefinition,
  CommandResult,
  SessionTargeting,
  WatchStream,
} from '../../commands/framework/define-command.js';
import { toYargsOptions } from '../../commands/framework/arg-builder.js';
import { explainMissingSessionAsync } from '../explain-missing-session.js';
import { describeError } from '../../messages/describe-error.js';
import { StudioBridgeError } from '../../messages/studio-bridge-error.js';
import { tryFindFolderInstanceAsync } from '../../deploy/deploy-places.js';
import {
  getWarnings,
  isJsonOutputEnabled,
  reportStaleHost,
  warnIfPluginStaleAsync,
} from '../cli-output-context.js';
import {
  ensureCurrentPluginAsync,
  resolvePluginUpdatePolicy,
  setPluginUpdatePolicy,
} from '../plugin-freshness.js';

/** Args injected by the adapter (not defined on CommandDefinition). */
export interface AdapterArgs {
  target?: string;
  context?: string;
  format?: string;
  output?: string;
  open?: boolean;
  watch?: boolean;
  interval?: number;
  updatePlugin?: boolean;
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
    autoHost?: boolean;
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

  setPluginUpdatePolicy(
    resolvePluginUpdatePolicy({
      updatePlugin: argv.updatePlugin as boolean | undefined,
      json: isJsonOutputEnabled() || argv.format === 'json',
      stdinIsTTY: process.stdin.isTTY,
      stderrIsTTY: process.stderr.isTTY,
    })
  );

  // Reuse existing connection if provided (watch mode), otherwise connect fresh
  const connection =
    existingConnection ??
    (await connect({
      timeoutMs: argv.timeout as number | undefined,
      remoteHost: argv.remote as string | undefined,
      local: argv.local as boolean | undefined,
      waitForSessions: def.scope === 'connection',
      autoHost: shouldAutoStartHost(argv.autohost as boolean | undefined),
    }));

  const targeting: SessionTargeting = {
    target: argv.target as string | undefined,
    context: argv.context as SessionContext | undefined,
  };

  // Connection commands start once Studios have connected, so this can look now
  if (def.scope === 'connection' && !def.coversAllSessions) {
    await tryTargetFolderInstanceAsync(connection, targeting);
  }

  reportStaleHost(connection);

  try {
    if (def.scope === 'session') {
      let session = await resolveTargetSessionAsync(connection, targeting);
      if (def.changesDataModel && !argv.allowEdit) {
        assertNotEditingDuringPlaytest(connection, session);
      }
      if (def.worksWithOutdatedPlugin) {
        await warnIfPluginStaleAsync([session.info]);
      } else {
        session = await ensureCurrentPluginAsync(connection, session);
      }
      return await (def.handler as any)(session, commandArgs, connection);
    }
    try {
      return await (def.handler as any)(connection, commandArgs, targeting);
    } finally {
      await warnIfPluginStaleAsync(connection.listSessions());
    }
  } finally {
    if (!existingConnection) {
      await connection.disconnectAsync();
    }
  }
}

/**
 * The session `targeting` names. When it names none and several Studios are
 * connected, the one with the current folder's deploy.nevermore.json place open.
 */
async function resolveTargetSessionAsync(
  connection: BridgeConnection,
  targeting: SessionTargeting
): Promise<BridgeSession> {
  try {
    return await connection.resolveSessionAsync(
      targeting.target,
      targeting.context
    );
  } catch (err) {
    if (
      err instanceof SessionNotFoundError &&
      (await tryTargetFolderInstanceAsync(connection, targeting))
    ) {
      return connection
        .resolveSessionAsync(targeting.target, targeting.context)
        .catch(async (retryErr: unknown) => {
          throw await explainMissingSessionAsync(connection, retryErr);
        });
    }
    throw await explainMissingSessionAsync(connection, err);
  }
}

/**
 * Without a --target, targets the one connected Studio that has the current
 * folder's deploy.nevermore.json place open, and says so.
 */
async function tryTargetFolderInstanceAsync(
  connection: BridgeConnection,
  targeting: SessionTargeting
): Promise<boolean> {
  if (targeting.target) {
    return false;
  }
  const folder = await tryFindFolderInstanceAsync(connection, process.cwd());
  if (!folder) {
    return false;
  }

  targeting.target = folder.instanceId;
  OutputHelper.hint(
    `Using ${folder.instanceId}, which has '${
      folder.deployPlace.selector
    }' of ${path.relative(process.cwd(), folder.deployPlace.configPath)} open`
  );
  return true;
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
    throw new StudioBridgeError({
      code: 'EDIT_DURING_PLAYTEST',
      message: `A playtest of '${session.info.placeName}' is running, so this would change Edit, not the playtest.`,
      fix: 'Add --context server to change the playtest, or --allow-edit to change Edit anyway.',
    });
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

export function resolveOutputFormat(
  def: CommandDefinition,
  format: string | undefined,
  outputPath: string | undefined
): string | undefined {
  if (format !== undefined) return format;
  if (def.cli?.rows && outputPath?.toLowerCase().endsWith('.csv')) {
    return 'csv';
  }
  return undefined;
}

function isSummaryOnStderr(
  def: CommandDefinition,
  format: string | undefined,
  watch: boolean
): boolean {
  return (
    def.cli?.output === 'data' &&
    !watch &&
    (format === undefined || format === 'text')
  );
}

function formatReportText(body: string, summary: string): string {
  const line = OutputHelper.formatDim(summary);
  return body === ''
    ? line
    : `${body}
${line}`;
}

export function renderResult(
  def: CommandDefinition,
  result: CommandResult,
  explicitFormat: string | undefined,
  summaryOnStderr = false
): string {
  if (explicitFormat === 'csv' && def.cli?.rows) {
    const { columns, rows } = def.cli.rows(result);
    return formatCsv(columns, rows);
  }

  if (explicitFormat === 'json') {
    if (def.cli?.json) return def.cli.json(result);
    return formatJson(injectWarnings(result), { pretty: process.stdout.isTTY });
  }

  const body = def.cli?.body?.(result) ?? '';
  return summaryOnStderr ? body : formatReportText(body, result.summary);
}

/**
 * Extract a Buffer from the result's binary field, or undefined if no
 * binary field is configured / extractable / requested. With an explicit
 * `--format` other than text the user wants that format, not raw bytes —
 * return undefined so the file reporter falls back to text rendering.
 */
function extractBinaryBuffer(
  def: CommandDefinition,
  result: unknown,
  format: string | undefined
): Buffer | undefined {
  if (format !== undefined && format !== 'text') return undefined;
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
      for (const name of Object.keys(def.cli?.removedOptions ?? {})) {
        yargs.option(name, { hidden: true });
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
        yargs.option('update-plugin', {
          type: 'boolean',
          default: false,
          describe:
            'If the Studio plugin is outdated, update it, wait for Studio to reload it, and go on, without asking',
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
        describe: def.cli?.rows
          ? 'Output format: text, json or csv (default: csv when --output ends in .csv)'
          : 'Output format: text or json',
      });
      yargs.option('output', {
        alias: 'o',
        type: 'string',
        describe: def.cli?.files
          ? 'Write output files into this directory'
          : 'Write output to file',
        ...(def.cli?.files ? { demandOption: true } : {}),
      });
      yargs.option('open', {
        type: 'boolean',
        default: false,
        describe: def.cli?.files
          ? 'Open the output directory after writing'
          : 'Open output file after writing',
      });

      const streamWatch = getStreamWatch(def);
      if (streamWatch) {
        yargs.option('watch', {
          alias: 'w',
          type: 'boolean',
          default: false,
          describe: streamWatch.description,
        });
      } else if (def.safety === 'read') {
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
      const explicitFormat = resolveOutputFormat(
        def,
        argv.format as string | undefined,
        argv.output as string | undefined
      );
      const files = def.cli?.files;
      const watch = !!argv.watch && def.safety === 'read';
      const summaryOnStderr = isSummaryOnStderr(def, explicitFormat, watch);
      const reporter = buildResultReporter<unknown>({
        outputPath: argv.output as string | undefined,
        watch,
        open: argv.open as boolean | undefined,
        intervalMs: argv.interval as number | undefined,
        render: (result) =>
          renderResult(
            def,
            result as CommandResult,
            explicitFormat,
            summaryOnStderr
          ),
        binary: (result) => extractBinaryBuffer(def, result, explicitFormat),
        ...(files ? { files: (result: unknown) => files(result as any) } : {}),
      });
      const connect =
        options?.lifecycle?.connectAsync.bind(options.lifecycle) ??
        BridgeConnection.connectAsync.bind(BridgeConnection);

      try {
        assertNoRemovedOptions(def, argv);
        assertSupportedFormat(def, argv.format as string | undefined);

        const streamWatch = getStreamWatch(def);
        if (argv.watch && streamWatch) {
          await runStreamWatchAsync(
            def,
            streamWatch,
            commandArgs,
            argv,
            toStreamFormat(explicitFormat),
            connect
          );
        } else if (argv.watch && def.safety === 'read') {
          await runWatchModeAsync(def, commandArgs, argv, reporter, connect);
        } else {
          await runOnceAsync(
            def,
            commandArgs,
            argv,
            reporter,
            connect,
            summaryOnStderr
          );
        }
      } catch (err) {
        reportError(err, explicitFormat === 'json');
        process.exit(1);
      }
    },
  };
}

export function reportError(err: unknown, json: boolean): void {
  const report = describeError(err, OutputHelper.isVerbose());
  if (json) {
    console.log(
      formatJson(injectWarnings({ success: false, ...report }), {
        pretty: process.stdout.isTTY,
      })
    );
    return;
  }
  OutputHelper.error(report.error);
  if (report.fix) OutputHelper.hint(report.fix);
  if (report.cause) OutputHelper.error(OutputHelper.formatDim(report.cause));
}

function assertNoRemovedOptions(
  def: CommandDefinition,
  argv: Record<string, unknown>
): void {
  for (const [name, replacement] of Object.entries(
    def.cli?.removedOptions ?? {}
  )) {
    if (argv[name] !== undefined) {
      throw new StudioBridgeError({
        code: 'REMOVED_OPTION',
        message: `--${name} was removed.`,
        fix: replacement,
      });
    }
  }
}

function assertSupportedFormat(
  def: CommandDefinition,
  format: string | undefined
): void {
  const formats = def.cli?.rows ? ['text', 'json', 'csv'] : ['text', 'json'];
  if (format === undefined || formats.includes(format)) return;
  throw new StudioBridgeError({
    code: 'INVALID_INPUT',
    message:
      format === 'csv'
        ? `'${[def.group, def.name]
            .filter(Boolean)
            .join(' ')}' has no table to write as CSV.`
        : `--format ${format} isn't a format.`,
    fix: `Use --format ${formats.join(' or ')}.`,
  });
}

function getStreamWatch(
  def: CommandDefinition
): CliWatchConfig<unknown> | undefined {
  return def.scope === 'session' ? def.cli?.watch : undefined;
}

function toStreamFormat(format: string | undefined): WatchStream['format'] {
  return format === 'json' || format === 'csv' ? format : 'text';
}

async function runStreamWatchAsync(
  def: CommandDefinition,
  watch: CliWatchConfig<unknown>,
  commandArgs: Record<string, unknown>,
  argv: Record<string, unknown>,
  format: WatchStream['format'],
  connect: CliLifecycleProvider['connectAsync']
): Promise<void> {
  const controller = new AbortController();
  const onSignal = (): void => {
    if (controller.signal.aborted) {
      process.exit(130);
    }
    controller.abort();
  };
  process.on('SIGINT', onSignal);
  process.on('SIGTERM', onSignal);

  const outputPath = argv.output as string | undefined;
  const file = outputPath
    ? fs.createWriteStream(path.resolve(outputPath))
    : undefined;
  const stream: WatchStream = {
    format,
    write: (text) => {
      if (file) file.write(text);
      else process.stdout.write(text);
    },
    signal: controller.signal,
  };

  try {
    await executeCommandAsync(
      {
        ...def,
        handler: (session: BridgeSession, args: unknown) =>
          watch.handler(session, args, stream),
      } as CommandDefinition,
      commandArgs,
      argv,
      connect
    );
  } finally {
    process.off('SIGINT', onSignal);
    process.off('SIGTERM', onSignal);
    if (file) {
      await new Promise<void>((resolve) => file.end(resolve));
    }
  }
}

async function runOnceAsync(
  def: CommandDefinition,
  commandArgs: Record<string, unknown>,
  argv: Record<string, unknown>,
  reporter: ResultReporter<unknown>,
  connect: CliLifecycleProvider['connectAsync'],
  summaryOnStderr: boolean
): Promise<void> {
  const result = await executeCommandAsync(def, commandArgs, argv, connect);

  await reporter.startAsync();
  reporter.onResult(result);
  await reporter.stopAsync();
  if (summaryOnStderr) {
    process.stderr.write(
      `${OutputHelper.formatDim((result as CommandResult).summary)}
`
    );
  }

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
          autoHost: shouldAutoStartHost(argv.autohost as boolean | undefined),
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
