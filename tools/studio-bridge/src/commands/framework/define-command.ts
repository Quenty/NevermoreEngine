/**
 * Core types and `defineCommand()` factory for the declarative command system.
 *
 * A single `CommandDefinition` drives CLI registration, MCP tool generation,
 * and terminal dot-command dispatch from one source of truth. The `scope`
 * discriminant determines the handler signature:
 *
 *   - `session`    — `(session: BridgeSession, args) => Promise<TResult>`
 *   - `connection` — `(connection: BridgeConnection, args) => Promise<TResult>`
 *   - `standalone` — `(args) => Promise<TResult>`
 */

import type { BridgeSession, BridgeConnection } from '../../bridge/index.js';
import type { McpContentBlock } from '../../mcp/adapters/mcp-adapter.js';
import type { OutputMode } from '../../cli/format-output.js';
import type { ArgDefinition } from './arg-builder.js';

// ---------------------------------------------------------------------------
// Brand
// ---------------------------------------------------------------------------

/**
 * Brand symbol used by the registry to identify command definitions when
 * scanning module exports via dynamic `import()`.
 */
export const COMMAND_BRAND = Symbol.for('studio-bridge:command');

// ---------------------------------------------------------------------------
// Enums / literals
// ---------------------------------------------------------------------------

/** Safety classification — drives targeting behavior in adapters. */
export type CommandSafety = 'read' | 'mutate' | 'none';

/** Scope determines handler signature and connection lifecycle. */
export type CommandScope = 'session' | 'connection' | 'standalone';

/** Category for CLI help grouping. */
export type CommandCategory = 'execution' | 'infrastructure';

// ---------------------------------------------------------------------------
// Adapter config
// ---------------------------------------------------------------------------

/** Optional MCP-specific overrides. Omit entirely to exclude from MCP. */
export interface McpConfig<TArgs, TResult> {
  /** Override the auto-generated tool name (default: `studio_{group}_{name}`). */
  toolName?: string;
  /** Map raw MCP input to handler args. */
  mapInput?: (input: Record<string, unknown>) => TArgs;
  /** Map handler result to MCP content blocks. Defaults to JSON text. */
  mapResult?: (result: TResult) => McpContentBlock[];
}

/** Optional CLI-specific overrides. */
export interface CliConfig<TResult> {
  /** Format the result for display. Falls back to JSON. */
  formatResult?: (result: TResult, mode: OutputMode) => string;
}

// ---------------------------------------------------------------------------
// Command input (what the user passes to defineCommand)
// ---------------------------------------------------------------------------

interface BaseFields<TArgs, TResult> {
  /** Group name (e.g. `"console"`, `"process"`). `null` for top-level. */
  group: string | null;
  /** Command name within the group (e.g. `"exec"`, `"list"`). */
  name: string;
  /** One-line description shown in help text. */
  description: string;
  /** Help category: `"execution"` or `"infrastructure"`. */
  category: CommandCategory;
  /** Safety classification for targeting behavior. */
  safety: CommandSafety;
  /** Argument definitions — keys are arg names. */
  args: Record<string, ArgDefinition>;
  /** MCP adapter config. Omit to exclude from MCP. */
  mcp?: McpConfig<TArgs, TResult>;
  /** CLI adapter config. */
  cli?: CliConfig<TResult>;
}

export interface SessionCommandInput<TArgs, TResult> extends BaseFields<TArgs, TResult> {
  scope: 'session';
  handler: (session: BridgeSession, args: TArgs) => Promise<TResult>;
}

export interface ConnectionCommandInput<TArgs, TResult> extends BaseFields<TArgs, TResult> {
  scope: 'connection';
  handler: (connection: BridgeConnection, args: TArgs) => Promise<TResult>;
}

export interface StandaloneCommandInput<TArgs, TResult> extends BaseFields<TArgs, TResult> {
  scope: 'standalone';
  handler: (args: TArgs) => Promise<TResult>;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type CommandInput<TArgs = any, TResult = any> =
  | SessionCommandInput<TArgs, TResult>
  | ConnectionCommandInput<TArgs, TResult>
  | StandaloneCommandInput<TArgs, TResult>;

// ---------------------------------------------------------------------------
// Branded definition (returned by defineCommand)
// ---------------------------------------------------------------------------

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type CommandDefinition<TArgs = any, TResult = any> =
  CommandInput<TArgs, TResult> & { readonly [COMMAND_BRAND]: true };

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

/**
 * Define a new command. Stamps the brand symbol so the registry can
 * identify it when scanning module exports.
 */
export function defineCommand<TArgs, TResult>(
  input: SessionCommandInput<TArgs, TResult>,
): CommandDefinition<TArgs, TResult>;
export function defineCommand<TArgs, TResult>(
  input: ConnectionCommandInput<TArgs, TResult>,
): CommandDefinition<TArgs, TResult>;
export function defineCommand<TArgs, TResult>(
  input: StandaloneCommandInput<TArgs, TResult>,
): CommandDefinition<TArgs, TResult>;
export function defineCommand(
  input: CommandInput,
): CommandDefinition {
  return { ...input, [COMMAND_BRAND]: true as const };
}

// ---------------------------------------------------------------------------
// Type guard
// ---------------------------------------------------------------------------

/**
 * Check whether a value is a branded `CommandDefinition`. Used by the
 * registry when scanning module exports via dynamic `import()`.
 */
export function isCommandDefinition(value: unknown): value is CommandDefinition {
  return (
    typeof value === 'object' &&
    value !== null &&
    (value as any)[COMMAND_BRAND] === true
  );
}
