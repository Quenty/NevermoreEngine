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

import type { BridgeSession, BridgeConnection } from '../../bridge/index.js';
import type { OutputMode } from '../../cli/format-output.js';
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

export type FormatResultMap<TResult> = Partial<
  Record<OutputMode, (result: TResult) => string>
>;

export interface CliConfig<TResult> {
  /** Adapter validates the user's --format choice against these keys and errors if unsupported. */
  formatResult?: FormatResultMap<TResult>;
  /** Field name containing base64 binary data for raw file writes via --output. */
  binaryField?: string;
}

interface BaseFields<TArgs, TResult> {
  /** `null` for top-level commands. */
  group: string | null;
  name: string;
  description: string;
  category: CommandCategory;
  safety: CommandSafety;
  args: Record<string, ArgDefinition>;
  cli?: CliConfig<TResult>;
}

export interface SessionCommandInput<TArgs, TResult>
  extends BaseFields<TArgs, TResult> {
  scope: 'session';
  handler: (session: BridgeSession, args: TArgs) => Promise<TResult>;
}

export interface ConnectionCommandInput<TArgs, TResult>
  extends BaseFields<TArgs, TResult> {
  scope: 'connection';
  handler: (connection: BridgeConnection, args: TArgs) => Promise<TResult>;
}

export interface StandaloneCommandInput<TArgs, TResult>
  extends BaseFields<TArgs, TResult> {
  scope: 'standalone';
  handler: (args: TArgs) => Promise<TResult>;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type CommandInput<TArgs = any, TResult = any> =
  | SessionCommandInput<TArgs, TResult>
  | ConnectionCommandInput<TArgs, TResult>
  | StandaloneCommandInput<TArgs, TResult>;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type CommandDefinition<TArgs = any, TResult = any> = CommandInput<
  TArgs,
  TResult
> & { readonly [COMMAND_BRAND]: true };

/**
 * Define a new command. Stamps the brand symbol so the registry can
 * identify it when scanning module exports.
 */
export function defineCommand<TArgs, TResult>(
  input: SessionCommandInput<TArgs, TResult>
): CommandDefinition<TArgs, TResult>;
export function defineCommand<TArgs, TResult>(
  input: ConnectionCommandInput<TArgs, TResult>
): CommandDefinition<TArgs, TResult>;
export function defineCommand<TArgs, TResult>(
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
