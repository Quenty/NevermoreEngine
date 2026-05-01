/**
 * `process info` — query the current Studio state (mode, place info)
 * from a connected session.
 */

import { defineCommand } from '../../framework/define-command.js';
import type { BridgeSession } from '../../../bridge/index.js';
import type { StudioState } from '../../../bridge/index.js';
import { colorizeState } from '../format-state.js';

export interface StateResult {
  state: StudioState;
  placeId: number;
  placeName: string;
  gameId: number;
  summary: string;
}

export async function queryStateHandlerAsync(
  session: BridgeSession
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

export function formatStateText(result: StateResult): string {
  return [
    `Mode:    ${colorizeState(result.state)}`,
    `Place:   ${result.placeName}`,
    `PlaceId: ${result.placeId}`,
    `GameId:  ${result.gameId}`,
  ].join('\n');
}

export const infoCommand = defineCommand({
  group: 'process',
  name: 'info',
  description: 'Query the current Studio state (mode, place info)',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {},
  cli: {
    format: formatStateText,
  },
  handler: async (session) => queryStateHandlerAsync(session),
});
