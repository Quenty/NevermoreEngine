/**
 * Handler for the `state` command. Queries the current Studio state
 * (mode, place info) from a connected session.
 */

import type { BridgeSession } from '../bridge/index.js';
import type { StudioState } from '../bridge/index.js';

export interface StateResult {
  state: StudioState;
  placeId: number;
  placeName: string;
  gameId: number;
  summary: string;
}

/**
 * Query the current Studio state from a connected session.
 */
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
