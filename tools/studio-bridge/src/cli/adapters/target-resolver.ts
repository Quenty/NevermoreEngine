/**
 * Unified target resolution for the `--target` flag.
 *
 * Replaces the old `--session`/`--instance` system with a single
 * `--target` option that supports:
 *
 *   - Explicit ID: `--target <sessionId>`
 *   - All sessions: `--target all`
 *   - Auto-resolve: omit `--target` → single session auto-selects
 *
 * Behavior varies by safety classification:
 *   - `read`   CLI: aggregate all sessions (no target required)
 *   - `mutate`  CLI: auto-resolve if 1, prompt/error if multiple
 *   - `none`:   no targeting needed
 *   - MCP:      always require explicit target, error with session list
 */

import type { BridgeConnection } from '../../bridge/index.js';
import type { BridgeSession, SessionContext, SessionInfo } from '../../bridge/index.js';
import type { CommandSafety } from '../../commands/framework/define-command.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface TargetResolveOptions {
  /** Explicit target from `--target` flag. */
  target?: string;
  /** Context filter from `--context` flag. */
  context?: SessionContext;
  /** Safety classification of the command. */
  safety: CommandSafety;
  /** Whether this is an MCP invocation (stricter targeting). */
  isMcp?: boolean;
}

/** Successful resolution — one or more sessions. */
export interface TargetResolved {
  sessions: BridgeSession[];
}

/** Structured error when target cannot be resolved. */
export interface MultipleSessionsError {
  error: 'multiple_sessions';
  hint: string;
  sessions: SessionInfo[];
}

// ---------------------------------------------------------------------------
// Resolver
// ---------------------------------------------------------------------------

/**
 * Resolve target session(s) from a `BridgeConnection` based on the
 * `--target` flag, safety classification, and invocation context.
 *
 * @throws {Error} When no sessions match or when multiple sessions
 *   exist and the command requires an explicit target.
 */
export async function resolveTargetAsync(
  connection: BridgeConnection,
  options: TargetResolveOptions,
): Promise<TargetResolved> {
  const { target, context, safety, isMcp } = options;

  // Explicit target
  if (target && target !== 'all') {
    const session = await connection.resolveSessionAsync(target, context);
    return { sessions: [session] };
  }

  // --target all: broadcast to all matching sessions
  if (target === 'all') {
    const sessions = filterSessions(connection, context);
    if (sessions.length === 0) {
      throw new Error(
        'No sessions connected. Is Studio running with the studio-bridge plugin?',
      );
    }
    return {
      sessions: sessions.map((info) => connection.getSession(info.sessionId)!),
    };
  }

  // No explicit target — behavior depends on safety and context
  const sessions = filterSessions(connection, context);

  if (sessions.length === 0) {
    throw new Error(
      'No sessions connected. Is Studio running with the studio-bridge plugin?',
    );
  }

  // MCP always requires explicit target when multiple sessions exist
  if (isMcp && sessions.length > 1) {
    throw new TargetRequiredError(sessions);
  }

  // CLI read commands: aggregate all sessions
  if (safety === 'read' && !isMcp) {
    return {
      sessions: sessions.map((info) => connection.getSession(info.sessionId)!),
    };
  }

  // Single session: auto-resolve
  if (sessions.length === 1) {
    const session = connection.getSession(sessions[0].sessionId)!;
    return { sessions: [session] };
  }

  // Multiple sessions + mutate: require explicit target
  throw new TargetRequiredError(sessions);
}

// ---------------------------------------------------------------------------
// Error class
// ---------------------------------------------------------------------------

export class TargetRequiredError extends Error {
  public readonly sessions: SessionInfo[];

  constructor(sessions: SessionInfo[]) {
    const listing = sessions
      .map(
        (s) =>
          `  - ${s.sessionId} (${s.placeName}, context=${s.context})`,
      )
      .join('\n');

    super(
      `Multiple sessions connected. Specify --target <id>:\n${listing}`,
    );
    this.name = 'TargetRequiredError';
    this.sessions = sessions;
  }

  /** Structured error payload for non-interactive / MCP responses. */
  toStructuredError(): MultipleSessionsError {
    return {
      error: 'multiple_sessions',
      hint: 'Specify --target <id>',
      sessions: this.sessions,
    };
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function filterSessions(
  connection: BridgeConnection,
  context?: SessionContext,
): SessionInfo[] {
  let sessions = connection.listSessions();
  if (context) {
    sessions = sessions.filter((s) => s.context === context);
  }
  return sessions;
}
