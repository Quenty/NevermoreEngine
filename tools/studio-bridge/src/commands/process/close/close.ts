/**
 * `process close` -- kill a Studio process (not yet implemented).
 *
 * Closing a Studio process requires matching a bridge session to an OS
 * process, which is non-trivial: the Roblox plugin API doesn't expose
 * the process ID, so the bridge would need to scan and heuristically
 * match OS processes. This command is stubbed until that infrastructure
 * exists.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession } from '../../../bridge/index.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ProcessCloseResult {
  sessionId: string;
  summary: string;
}

interface ProcessCloseArgs {
  force?: boolean;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

export async function processCloseHandlerAsync(
  session: BridgeSession,
): Promise<ProcessCloseResult> {
  return {
    sessionId: session.info.sessionId,
    summary: `process close is not yet implemented. Closing a Studio process requires OS process scanning which has not been built yet.`,
  };
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const processCloseCommand = defineCommand<ProcessCloseArgs, ProcessCloseResult>({
  group: 'process',
  name: 'close',
  description: 'Kill a Studio process (not yet implemented)',
  category: 'infrastructure',
  safety: 'mutate',
  scope: 'session',
  args: {
    force: arg.flag({
      description: 'Force shutdown without confirmation',
      alias: 'f',
    }),
  },
  handler: async (session) => processCloseHandlerAsync(session),
  mcp: {
    mapResult: (result) => [
      {
        type: 'text' as const,
        text: JSON.stringify({
          sessionId: result.sessionId,
          summary: result.summary,
        }),
      },
    ],
  },
});
