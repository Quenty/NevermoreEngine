/**
 * `process info` — report on one Studio session: its place and run mode, the
 * playtest running in its Studio, its window, and whether its plugin is
 * current.
 */

import { OutputHelper } from '@quenty/cli-output-helpers';
import { defineCommand } from '../../framework/define-command.js';
import type {
  BridgeConnection,
  BridgeSession,
  SessionContext,
  SessionInfo,
  SessionOrigin,
  StudioState,
} from '../../../bridge/index.js';
import { colorizeState } from '../format-state.js';
import {
  listStudioProcessesAsync,
  matchStudioProcesses,
} from '../../../process/studio-process-closer.js';
import { tryGetStudioWindowStateAsync } from '../../../process/studio-window-state.js';
import { getPluginBuildVersionAsync } from '../../../plugin/plugin-build-version.js';

export interface PlaytestInfo {
  mode: 'play' | 'run';
  /** Set for a multiplayer test. */
  players?: number;
  sessions: Array<{
    sessionId: string;
    context: SessionContext;
    playerName?: string;
  }>;
}

export interface StateResult {
  sessionId: string;
  instanceId: string;
  context: SessionContext;
  origin: SessionOrigin;
  /** The run mode of this session's own DataModel. */
  state: StudioState;
  placeId: number;
  placeName: string;
  gameId: number;
  /** The camera viewport in pixels. Absent without a camera. */
  viewportSize?: [number, number];
  /** Absent from older plugins. */
  studioVersion?: string;
  plugin: {
    version: string;
    /** The version `studio-bridge plugin install` would install. */
    expectedVersion: string;
    upToDate: boolean;
  };
  /**
   * The playtest running in this session's Studio, as seen through the
   * sessions it opened. Absent when none is running or its sessions are not
   * connected.
   */
  playtest?: PlaytestInfo;
  /** The Studio window showing the place. Absent when it cannot be told apart. */
  window?: {
    pid: number;
    focused: boolean;
    minimized: boolean;
  };
  connectedAt: string;
  summary: string;
}

export async function queryStateHandlerAsync(
  session: BridgeSession,
  connection?: BridgeConnection
): Promise<StateResult> {
  // Listed sessions carry the edit session's place name for a playtest
  const listed = connection
    ?.listSessions()
    .find((s) => s.sessionId === session.info.sessionId);
  const playtest = connection
    ? describePlaytest(connection.listSessions(), session.info.instanceId)
    : undefined;
  // Each process of a multiplayer test has its own window; otherwise a
  // playtest shows in the edit window
  const ownWindow =
    session.info.context !== 'edit' && playtest?.players !== undefined;
  const [result, expectedVersion] = await Promise.all([
    session.queryStateAsync(),
    getPluginBuildVersionAsync(),
  ]);
  const window = await tryGetWindowAsync(
    ownWindow ? [result.placeName] : [result.placeName, listed?.placeName]
  );

  return {
    sessionId: session.info.sessionId,
    instanceId: session.info.instanceId,
    context: session.info.context,
    origin: session.info.origin,
    state: result.state,
    placeId: result.placeId,
    placeName: listed?.placeName || result.placeName,
    gameId: result.gameId,
    viewportSize: result.viewportSize,
    studioVersion: result.studioVersion,
    plugin: {
      version: session.info.pluginVersion,
      expectedVersion,
      upToDate: session.info.pluginVersion === expectedVersion,
    },
    playtest,
    window,
    connectedAt: new Date(session.info.connectedAt).toISOString(),
    summary: `Mode: ${result.state}, Place: ${result.placeName} (${result.placeId})`,
  };
}

/** The playtest of `instanceId`, from the sessions it opened. */
export function describePlaytest(
  sessions: SessionInfo[],
  instanceId: string
): PlaytestInfo | undefined {
  const playtestSessions = sessions.filter(
    (s) => s.instanceId === instanceId && s.context !== 'edit'
  );
  if (playtestSessions.length === 0) return undefined;

  const clients = playtestSessions.filter((s) => s.context === 'client');
  const isMultiplayer = clients.some(
    (s) => s.sessionId !== `${instanceId}-client`
  );

  return {
    mode: clients.length > 0 ? 'play' : 'run',
    players: isMultiplayer ? clients.length : undefined,
    sessions: playtestSessions.map((s) => ({
      sessionId: s.sessionId,
      context: s.context,
      playerName: s.playerName,
    })),
  };
}

/**
 * The Studio window titled with the first of `placeNames` that any window
 * has, when exactly one does. A multiplayer test's processes title their
 * windows with their own DataModel's name, and its clients all share one;
 * a single-process playtest shares the edit window.
 */
async function tryGetWindowAsync(
  placeNames: Array<string | undefined>
): Promise<StateResult['window']> {
  const processes = await listStudioProcessesAsync().catch(() => []);
  for (const placeName of placeNames) {
    if (!placeName) continue;
    const matches = matchStudioProcesses(processes, placeName);
    if (matches.length === 0) continue;
    if (matches.length > 1) return undefined;

    const pid = matches[0].pid;
    const state = await tryGetStudioWindowStateAsync(pid);
    return state ? { pid, ...state } : undefined;
  }
  return undefined;
}

function formatAge(isoTime: string): string {
  const seconds = Math.max(
    0,
    Math.round((Date.now() - Date.parse(isoTime)) / 1000)
  );
  if (seconds < 60) return `${seconds}s ago`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  return `${Math.floor(seconds / 3600)}h ${Math.floor(
    (seconds % 3600) / 60
  )}m ago`;
}

function formatPlaytest(playtest: PlaytestInfo | undefined): string {
  if (!playtest) return 'none running';
  const kind =
    playtest.players !== undefined
      ? `multiplayer, ${playtest.players} player${
          playtest.players === 1 ? '' : 's'
        }`
      : `${playtest.mode} mode`;
  return `running (${kind}): ${playtest.sessions
    .map((s) => s.sessionId)
    .join(', ')}`;
}

export function formatStateText(result: StateResult): string {
  const lines = [
    `Session:  ${OutputHelper.formatHint(result.sessionId)} (${
      result.context
    }, ${result.origin}, connected ${formatAge(result.connectedAt)})`,
    `Mode:     ${colorizeState(result.state)}`,
    `Playtest: ${formatPlaytest(result.playtest)}`,
    `Place:    ${result.placeName} (PlaceId ${result.placeId}, GameId ${result.gameId})`,
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
  if (result.studioVersion) {
    lines.push(`Studio:   ${result.studioVersion}`);
  }
  lines.push(
    `Plugin:   ${result.plugin.version || 'unknown'} ${
      result.plugin.upToDate
        ? '(up to date)'
        : OutputHelper.formatWarning(
            `(out of date, expected ${result.plugin.expectedVersion}; run 'studio-bridge plugin install')`
          )
    }`
  );
  return lines.join('\n');
}

export const infoCommand = defineCommand({
  group: 'process',
  name: 'info',
  description:
    'Report on a Studio session: mode, playtest, place, window and plugin version',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {},
  cli: {
    format: formatStateText,
  },
  handler: async (session, _args, connection) =>
    queryStateHandlerAsync(session, connection),
});
