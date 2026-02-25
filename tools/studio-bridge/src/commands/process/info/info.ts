/**
 * `process info` — query the current Studio state (mode, place info)
 * from a connected session.
 */

import { defineCommand } from '../../framework/define-command.js';
import type { BridgeSession } from '../../../bridge/index.js';
import type { StudioState } from '../../../bridge/index.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface StateResult {
  state: StudioState;
  placeId: number;
  placeName: string;
  gameId: number;
  summary: string;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

export async function queryStateHandlerAsync(
  session: BridgeSession,
): Promise<StateResult> {
  const result = await session.queryStateAsync();

  return {
    state: result.state,
    placeId: result.placeId,
    placeName: result.placeName,
    gameId: result.gameId,
    summary: `Mode: ${result.state}, Place: ${result.placeName} (${result.placeId})`,
  };
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const infoCommand = defineCommand({
  group: 'process',
  name: 'info',
  description: 'Query the current Studio state (mode, place info)',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {},
  handler: async (session) => queryStateHandlerAsync(session),
  mcp: {
    mapResult: (result) => [
      {
        type: 'text' as const,
        text: JSON.stringify({
          state: result.state,
          placeId: result.placeId,
          placeName: result.placeName,
          gameId: result.gameId,
        }),
      },
    ],
  },
});
