/**
 * Dot-command dispatcher for terminal mode. Maps dot-commands to shared
 * command handlers in src/commands/. Manages the active session state
 * for commands that require a connected session.
 *
 * Built-in commands (.help, .exit, .clear, .run) are handled separately
 * by the terminal editor. This module handles bridge commands:
 * .state, .screenshot, .logs, .query, .sessions, .connect, .disconnect
 */

import type { BridgeConnection } from '../../../bridge/index.js';
import type { BridgeSession } from '../../../bridge/index.js';
import {
  queryStateHandlerAsync,
  captureScreenshotHandlerAsync,
  queryLogsHandlerAsync,
  queryDataModelHandlerAsync,
  listSessionsHandlerAsync,
  connectHandlerAsync,
  disconnectHandler,
} from '../../../commands/index.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface DotCommandEntry {
  name: string;
  description: string;
  usage?: string;
}

export interface DotCommandResult {
  handled: boolean;
  output?: string;
  error?: string;
}

// ---------------------------------------------------------------------------
// Command registry (static metadata)
// ---------------------------------------------------------------------------

const BRIDGE_COMMANDS: DotCommandEntry[] = [
  { name: '.sessions', description: 'List connected Studio sessions' },
  { name: '.connect', description: 'Connect to a session by ID', usage: '.connect <session-id>' },
  { name: '.disconnect', description: 'Disconnect from the active session' },
  { name: '.state', description: 'Query Studio state (mode, place info)' },
  { name: '.screenshot', description: 'Capture a viewport screenshot' },
  { name: '.logs', description: 'Show recent log entries' },
  { name: '.query', description: 'Query the DataModel instance tree', usage: '.query <path>' },
];

const BUILTIN_COMMANDS: DotCommandEntry[] = [
  { name: '.help', description: 'Show this help message' },
  { name: '.exit', description: 'Exit terminal mode' },
  { name: '.run', description: 'Read and execute a Luau file', usage: '.run <file>' },
  { name: '.clear', description: 'Clear the editor buffer' },
];

// ---------------------------------------------------------------------------
// TerminalDotCommands
// ---------------------------------------------------------------------------

export class TerminalDotCommands {
  private _connection: BridgeConnection | undefined;
  private _activeSession: BridgeSession | undefined;

  constructor(connection?: BridgeConnection) {
    this._connection = connection;
  }

  /** The currently active session for bridge commands. */
  get activeSession(): BridgeSession | undefined {
    return this._activeSession;
  }

  /** Set the active session directly (e.g. after auto-resolve). */
  set activeSession(session: BridgeSession | undefined) {
    this._activeSession = session;
  }

  /** Update the connection used for session-level commands. */
  set connection(conn: BridgeConnection | undefined) {
    this._connection = conn;
  }

  /**
   * Check whether a dot-command is a bridge command handled by this
   * dispatcher (as opposed to a built-in editor command).
   */
  isBridgeCommand(commandName: string): boolean {
    const normalized = commandName.toLowerCase();
    return BRIDGE_COMMANDS.some((c) => c.name === normalized);
  }

  /**
   * Generate help text listing all available commands (built-in + bridge).
   */
  generateHelpText(): string {
    const lines: string[] = [''];
    lines.push('\x1b[2mCommands:\x1b[0m');

    for (const cmd of [...BUILTIN_COMMANDS, ...BRIDGE_COMMANDS]) {
      const label = cmd.usage ?? cmd.name;
      const padding = Math.max(2, 18 - label.length);
      lines.push(`  ${label}${' '.repeat(padding)}${cmd.description}`);
    }

    lines.push('');
    lines.push('\x1b[2mKeybindings:\x1b[0m');
    lines.push('  Enter          New line');
    lines.push('  Ctrl+Enter     Execute buffer');
    lines.push('  Ctrl+C         Clear buffer (or exit if empty)');
    lines.push('  Ctrl+D         Exit');
    lines.push('  Tab            Insert 2 spaces');
    lines.push('  Arrow keys     Move cursor');
    lines.push('');

    return lines.join('\n');
  }

  /**
   * Dispatch a bridge dot-command. Returns a result with output text
   * or an error message. Returns `{ handled: false }` if the command
   * is not a recognized bridge command.
   */
  async dispatchAsync(input: string): Promise<DotCommandResult> {
    const parts = input.trim().split(/\s+/);
    const cmd = parts[0].toLowerCase();

    switch (cmd) {
      case '.sessions':
        return this._handleSessionsAsync();

      case '.connect':
        return this._handleConnectAsync(parts.slice(1).join(' ').trim());

      case '.disconnect':
        return this._handleDisconnect();

      case '.state':
        return this._handleStateAsync();

      case '.screenshot':
        return this._handleScreenshotAsync();

      case '.logs':
        return this._handleLogsAsync();

      case '.query':
        return this._handleQueryAsync(parts.slice(1).join(' ').trim());

      default:
        return { handled: false };
    }
  }

  // -----------------------------------------------------------------------
  // Private handlers
  // -----------------------------------------------------------------------

  private async _handleSessionsAsync(): Promise<DotCommandResult> {
    if (!this._connection) {
      return { handled: true, error: 'No bridge connection available.' };
    }

    try {
      const result = await listSessionsHandlerAsync(this._connection);
      return { handled: true, output: result.summary };
    } catch (err) {
      return { handled: true, error: this._formatError(err) };
    }
  }

  private async _handleConnectAsync(sessionId: string): Promise<DotCommandResult> {
    if (!sessionId) {
      return { handled: true, error: 'Usage: .connect <session-id>' };
    }

    if (!this._connection) {
      return { handled: true, error: 'No bridge connection available.' };
    }

    try {
      const result = await connectHandlerAsync(this._connection, { sessionId });
      this._activeSession = this._connection.getSession(result.sessionId);
      return { handled: true, output: result.summary };
    } catch (err) {
      return { handled: true, error: this._formatError(err) };
    }
  }

  private _handleDisconnect(): DotCommandResult {
    const result = disconnectHandler();
    this._activeSession = undefined;
    return { handled: true, output: result.summary };
  }

  private async _handleStateAsync(): Promise<DotCommandResult> {
    const session = this._requireSession();
    if (!session) {
      return { handled: true, error: 'No active session. Use .connect <id> or .sessions to see available sessions.' };
    }

    try {
      const result = await queryStateHandlerAsync(session);
      return { handled: true, output: result.summary };
    } catch (err) {
      return { handled: true, error: this._formatError(err) };
    }
  }

  private async _handleScreenshotAsync(): Promise<DotCommandResult> {
    const session = this._requireSession();
    if (!session) {
      return { handled: true, error: 'No active session. Use .connect <id> or .sessions to see available sessions.' };
    }

    try {
      const result = await captureScreenshotHandlerAsync(session);
      return { handled: true, output: result.summary };
    } catch (err) {
      return { handled: true, error: this._formatError(err) };
    }
  }

  private async _handleLogsAsync(): Promise<DotCommandResult> {
    const session = this._requireSession();
    if (!session) {
      return { handled: true, error: 'No active session. Use .connect <id> or .sessions to see available sessions.' };
    }

    try {
      const result = await queryLogsHandlerAsync(session);

      const lines: string[] = [];
      for (const entry of result.entries) {
        lines.push(`[${entry.level}] ${entry.body}`);
      }
      lines.push(result.summary);

      return { handled: true, output: lines.join('\n') };
    } catch (err) {
      return { handled: true, error: this._formatError(err) };
    }
  }

  private async _handleQueryAsync(queryPath: string): Promise<DotCommandResult> {
    if (!queryPath) {
      return { handled: true, error: 'Usage: .query <path> (e.g. .query game.Workspace)' };
    }

    const session = this._requireSession();
    if (!session) {
      return { handled: true, error: 'No active session. Use .connect <id> or .sessions to see available sessions.' };
    }

    try {
      const result = await queryDataModelHandlerAsync(session, {
        path: queryPath,
        children: true,
      });
      return { handled: true, output: result.summary };
    } catch (err) {
      return { handled: true, error: this._formatError(err) };
    }
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  private _requireSession(): BridgeSession | undefined {
    return this._activeSession;
  }

  private _formatError(err: unknown): string {
    return err instanceof Error ? err.message : String(err);
  }
}

// ---------------------------------------------------------------------------
// Exported helpers for testing
// ---------------------------------------------------------------------------

export function getBridgeCommandNames(): string[] {
  return BRIDGE_COMMANDS.map((c) => c.name);
}

export function getAllCommandNames(): string[] {
  return [...BUILTIN_COMMANDS, ...BRIDGE_COMMANDS].map((c) => c.name);
}
