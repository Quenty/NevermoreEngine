/**
 * Core types and `defineCommand()` factory for the declarative command system.
 *
 * A single `CommandDefinition` drives CLI registration. The `scope`
 * discriminant determines the handler signature:
 *
 *   - `session`    — `(session: BridgeSession, args) => Promise<TResult>`
 *   - `connection` — `(connection: BridgeConnection, args) => Promise<TResult>`
 *   - `standalone` — `(args) => Promise<TResult>`
 */

import type {
  BridgeSession,
  BridgeConnection,
  SessionContext,
} from '../../bridge/index.js';
import type {
  CsvValue,
  OutputFile,
} from '@quenty/cli-output-helpers/reporting';
import type { ArgDefinition } from './arg-builder.js';

/**
 * Brand symbol used by the registry to identify command definitions when
 * scanning module exports via dynamic `import()`.
 */
export const COMMAND_BRAND = Symbol.for('studio-bridge:command');

/** Safety classification — drives targeting behavior in adapters. */
export type CommandSafety = 'read' | 'mutate' | 'none';

export type CommandScope = 'session' | 'connection' | 'standalone';

export type CommandCategory = 'execution' | 'infrastructure';

/** What a command's `cli.watch` handler streams its output through. */
export interface WatchStream {
  format: 'text' | 'json' | 'csv';
  write: (text: string) => void;
  signal: AbortSignal;
}

/** Streams a session command's output under `--watch`, instead of re-running it on an interval. */
export interface CliWatchConfig<TArgs> {
  description: string;
  handler: (
    session: BridgeSession,
    args: TArgs,
    stream: WatchStream
  ) => Promise<void>;
}

/** What a command result always has. */
export interface CommandResult {
  summary: string;
}

/** A result as columns and rows, which `--format csv` writes. */
export interface ResultTable {
  columns: readonly string[];
  rows: readonly (readonly CsvValue[])[];
}

/** Where text output puts the summary. */
export type CliOutputKind = 'report' | 'data';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export interface CliConfig<TResult, TArgs = any> {
  body?: (result: TResult) => string;
  output?: CliOutputKind;
  /**
   * Override the default JSON output (which is `formatJson(result)`). Use
   * this when the result has fields that don't belong in machine output —
   * e.g. dropping a base64 binary field.
   */
  json?: (result: TResult) => string;
  /** Field name containing base64 binary data for raw file writes via --output. */
  binaryField?: string;
  rows?: (result: TResult) => ResultTable;
  files?: (result: TResult) => OutputFile[];
  watch?: CliWatchConfig<TArgs>;
  removedOptions?: Record<string, string>;
  hiddenAliases?: string[];
}

interface BaseFields<TArgs, TResult extends CommandResult> {
  /** `null` for top-level commands. */
  group: string | null;
  name: string;
  description: string;
  category: CommandCategory;
  safety: CommandSafety;
  /**
   * Changes the DataModel. Refused on an edit session while a playtest of it
   * runs, since those edits are not what the playtest is running, unless
   * `--allow-edit` is passed.
   */
  changesDataModel?: boolean;
  /**
   * Reports on every session, so without `--target` it is not narrowed to the
   * Studio that has the current folder's `deploy.nevermore.json` place open.
   */
  coversAllSessions?: boolean;
  worksWithOutdatedPlugin?: boolean;
  args: Record<string, ArgDefinition>;
  cli?: CliConfig<TResult, TArgs>;
}

export interface SessionCommandInput<TArgs, TResult extends CommandResult>
  extends BaseFields<TArgs, TResult> {
  scope: 'session';
  handler: (
    session: BridgeSession,
    args: TArgs,
    connection: BridgeConnection
  ) => Promise<TResult>;
}

/** The `--target` and `--context` flags, for handlers that resolve sessions themselves. */
export interface SessionTargeting {
  target?: string;
  context?: SessionContext;
}

export interface ConnectionCommandInput<TArgs, TResult extends CommandResult>
  extends BaseFields<TArgs, TResult> {
  scope: 'connection';
  handler: (
    connection: BridgeConnection,
    args: TArgs,
    targeting: SessionTargeting
  ) => Promise<TResult>;
}

export interface StandaloneCommandInput<TArgs, TResult extends CommandResult>
  extends BaseFields<TArgs, TResult> {
  scope: 'standalone';
  handler: (args: TArgs) => Promise<TResult>;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type CommandInput<TArgs = any, TResult extends CommandResult = any> =
  | SessionCommandInput<TArgs, TResult>
  | ConnectionCommandInput<TArgs, TResult>
  | StandaloneCommandInput<TArgs, TResult>;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type CommandDefinition<
  TArgs = any,
  TResult extends CommandResult = any
> = CommandInput<TArgs, TResult> & { readonly [COMMAND_BRAND]: true };

/**
 * Define a new command. Stamps the brand symbol so the registry can
 * identify it when scanning module exports.
 */
export function defineCommand<TArgs, TResult extends CommandResult>(
  input: SessionCommandInput<TArgs, TResult>
): CommandDefinition<TArgs, TResult>;
export function defineCommand<TArgs, TResult extends CommandResult>(
  input: ConnectionCommandInput<TArgs, TResult>
): CommandDefinition<TArgs, TResult>;
export function defineCommand<TArgs, TResult extends CommandResult>(
  input: StandaloneCommandInput<TArgs, TResult>
): CommandDefinition<TArgs, TResult>;
export function defineCommand(input: CommandInput): CommandDefinition {
  return { ...input, [COMMAND_BRAND]: true as const };
}

/**
 * Check whether a value is a branded `CommandDefinition`. Used by the
 * registry when scanning module exports via dynamic `import()`.
 */
export function isCommandDefinition(
  value: unknown
): value is CommandDefinition {
  return (
    typeof value === 'object' &&
    value !== null &&
    (value as any)[COMMAND_BRAND] === true
  );
}
