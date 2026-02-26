/**
 * `process info` — query the current Studio state (mode, place info)
 * from a connected session.
 */

import { defineCommand } from '../../framework/define-command.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
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
// Formatters
// ---------------------------------------------------------------------------

function colorizeState(state: StudioState): string {
  switch (state) {
    case 'Edit': return OutputHelper.formatInfo(state);
    case 'Play':
    case 'Run': return OutputHelper.formatSuccess(state);
    case 'Paused': return OutputHelper.formatWarning(state);
    default: return state;
  }
}

export function formatStateText(result: StateResult): string {
  return [
    `Mode:    ${colorizeState(result.state)}`,
    `Place:   ${result.placeName}`,
    `PlaceId: ${result.placeId}`,
    `GameId:  ${result.gameId}`,
  ].join('\n');
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
  cli: {
    formatResult: {
      text: formatStateText,
      table: formatStateText,
    },
  },
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
