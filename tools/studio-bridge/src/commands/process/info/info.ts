/**
 * `process info` — query the current Studio state (mode, place info, window)
 * from a connected session.
 */

import { defineCommand } from '../../framework/define-command.js';
import type { BridgeSession } from '../../../bridge/index.js';
import type { StudioState } from '../../../bridge/index.js';
import { colorizeState } from '../format-state.js';
import {
  listStudioProcessesAsync,
  matchStudioProcesses,
} from '../../../process/studio-process-closer.js';
import { tryGetStudioWindowStateAsync } from '../../../process/studio-window-state.js';

export interface StateResult {
  state: StudioState;
  placeId: number;
  placeName: string;
  gameId: number;
  /** The camera viewport in pixels. Absent without a camera. */
  viewportSize?: [number, number];
  /** The Studio window showing the place. Absent when it cannot be told apart. */
  window?: {
    pid: number;
    focused: boolean;
    minimized: boolean;
  };
  summary: string;
}

export async function queryStateHandlerAsync(
  session: BridgeSession
): Promise<StateResult> {
  const result = await session.queryStateAsync();
  const window = await tryGetWindowAsync(result.placeName);

  return {
    state: result.state,
    placeId: result.placeId,
    placeName: result.placeName,
    gameId: result.gameId,
    viewportSize: result.viewportSize,
    window,
    summary: `Mode: ${result.state}, Place: ${result.placeName} (${result.placeId})`,
  };
}

async function tryGetWindowAsync(
  placeName: string
): Promise<StateResult['window']> {
  const processes = await listStudioProcessesAsync().catch(() => []);
  const matches = matchStudioProcesses(processes, placeName);
  if (matches.length !== 1) return undefined;

  const pid = matches[0].pid;
  const state = await tryGetStudioWindowStateAsync(pid);
  return state ? { pid, ...state } : undefined;
}

export function formatStateText(result: StateResult): string {
  const lines = [
    `Mode:     ${colorizeState(result.state)}`,
    `Place:    ${result.placeName}`,
    `PlaceId:  ${result.placeId}`,
    `GameId:   ${result.gameId}`,
  ];
  if (result.viewportSize) {
    lines.push(`Viewport: ${result.viewportSize[0]}x${result.viewportSize[1]}`);
  }
  if (result.window) {
    const { pid, focused, minimized } = result.window;
    lines.push(
      `Window:   pid ${pid}, ${minimized ? 'minimized' : 'open'}, ${
        focused ? 'focused' : 'not focused'
      }`
    );
  }
  return lines.join('\n');
}

export const infoCommand = defineCommand({
  group: 'process',
  name: 'info',
  description: 'Query the current Studio state (mode, place info, window)',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {},
  cli: {
    format: formatStateText,
  },
  handler: async (session) => queryStateHandlerAsync(session),
});
