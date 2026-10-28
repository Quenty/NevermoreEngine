/**
 * `process close` — close the Studio process a session belongs to, or the
 * Studio showing a `deploy.nevermore.json` target's place.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeConnection, BridgeSession } from '../../../bridge/index.js';
import {
  closeStudioProcessAsync,
  listStudioProcessesAsync,
  matchStudioProcesses,
  matchStudioProcessesByPlaceId,
  type RunningStudioProcess,
} from '../../../process/studio-process-closer.js';
import {
  findInstancesShowingPlaceAsync,
  resolveDeployPlaceAsync,
} from '../../../deploy/deploy-places.js';
import { explainMissingPlaytestContextAsync } from '../../playtest/playtest-sessions.js';
import { describePlaytest } from '../info/info.js';

export interface ProcessCloseResult {
  success: boolean;
  sessionId?: string;
  /** The `deploy.nevermore.json` target whose Studio was closed, if one was named. */
  deployTarget?: string;
  pid?: number;
  summary: string;
}

export interface ProcessCloseOptions {
  force?: boolean;
  pid?: number;
}

interface ProcessCloseArgs {
  deployTarget?: string;
  force?: boolean;
  pid?: number;
}

export async function processCloseHandlerAsync(
  session: BridgeSession,
  options: ProcessCloseOptions = {},
  connection?: BridgeConnection
): Promise<ProcessCloseResult> {
  const { sessionId, instanceId, context } = session.info;
  const sessions = connection?.listSessions() ?? [];
  // Listed sessions carry the edit session's place name for a playtest
  const placeName =
    sessions.find((s) => s.sessionId === sessionId)?.placeName ||
    session.info.placeName;

  const isMultiplayerProcess =
    context !== 'edit' &&
    describePlaytest(sessions, instanceId)?.playerCount !== undefined;
  if (isMultiplayerProcess && options.pid === undefined) {
    return {
      success: false,
      sessionId,
      summary: `'${sessionId}' runs in its own process of a multiplayer test. End the test with 'studio-bridge playtest stop', remove a player with 'studio-bridge playtest player remove', or pass --pid.`,
    };
  }

  const processes = await listStudioProcessesAsync();
  let candidates =
    options.pid !== undefined
      ? processes.filter((proc) => proc.pid === options.pid)
      : matchStudioProcesses(processes, placeName);
  if (candidates.length === 0 && options.pid === undefined) {
    // A cloud place loads after the plugin registers, so its registered id can be 0
    const placeId = (await session.queryStateAsync().catch(() => undefined))
      ?.placeId;
    candidates = matchStudioProcesses(processes, placeName, placeId);
  }

  return closeCandidateAsync(candidates, `'${placeName}'`, options, {
    sessionId,
  });
}

/**
 * Close the Studio showing a target's place from the nearest
 * `deploy.nevermore.json`: a connected one, or else one launched with it.
 */
export async function closeDeployTargetAsync(
  connection: BridgeConnection,
  deployTarget: string,
  options: ProcessCloseOptions = {},
  cwd = process.cwd()
): Promise<ProcessCloseResult> {
  const deployPlace = await resolveDeployPlaceAsync(cwd, deployTarget);
  if (!deployPlace) {
    throw new Error(`Target '${deployTarget}' not found`);
  }
  const { placeId } = deployPlace.place;
  const showing = `'${deployPlace.selector}' (place ${placeId})`;
  const base = { deployTarget: deployPlace.selector };

  const instanceIds = await findInstancesShowingPlaceAsync(connection, placeId);
  if (instanceIds.length > 1) {
    return {
      ...base,
      success: false,
      summary: `${
        instanceIds.length
      } Studios have ${showing} open (${instanceIds.join(
        ', '
      )}). Pick one with --target.`,
    };
  }
  if (instanceIds.length === 1) {
    const session = await connection.resolveSessionAsync(
      instanceIds[0],
      'edit'
    );
    return {
      ...(await processCloseHandlerAsync(session, options, connection)),
      ...base,
    };
  }

  const processes = await listStudioProcessesAsync();
  const candidates =
    options.pid !== undefined
      ? processes.filter((proc) => proc.pid === options.pid)
      : matchStudioProcessesByPlaceId(processes, placeId);
  return closeCandidateAsync(candidates, showing, options, base);
}

async function closeCandidateAsync(
  candidates: RunningStudioProcess[],
  showing: string,
  options: ProcessCloseOptions,
  base: Pick<ProcessCloseResult, 'sessionId' | 'deployTarget'>
): Promise<ProcessCloseResult> {
  const fail = (summary: string, pid?: number): ProcessCloseResult => ({
    ...base,
    success: false,
    pid,
    summary,
  });

  if (candidates.length === 0) {
    return fail(
      options.pid !== undefined
        ? `No Studio process with pid ${options.pid}`
        : `No Studio window is showing ${showing}`
    );
  }

  if (candidates.length > 1) {
    const pids = candidates.map((proc) => proc.pid).join(', ');
    return fail(
      `${candidates.length} Studio windows are showing ${showing} (pids ${pids}). Pick one with --pid.`
    );
  }

  const { pid } = candidates[0];
  const exited = await closeStudioProcessAsync(pid, { force: options.force });
  if (!exited) {
    return fail(
      options.force
        ? `Studio (pid ${pid}) did not exit`
        : `Studio (pid ${pid}) is still open, likely asking to save. Use --force to close without saving.`,
      pid
    );
  }

  return {
    ...base,
    success: true,
    pid,
    summary: `Closed Studio (pid ${pid}) showing ${showing}`,
  };
}

export const processCloseCommand = defineCommand<
  ProcessCloseArgs,
  ProcessCloseResult
>({
  group: 'process',
  name: 'close',
  description:
    "Close a Studio: the one a session belongs to, or the one showing a deploy.nevermore.json target's place",
  category: 'infrastructure',
  safety: 'mutate',
  scope: 'connection',
  args: {
    deployTarget: arg.positional({
      description:
        'deploy.nevermore.json target whose Studio to close, e.g. test or integration.places.hub',
      required: false,
    }),
    force: arg.flag({
      description: 'Kill Studio without letting it prompt to save',
      alias: 'f',
    }),
    pid: arg.option({
      description: 'Studio process id, when several windows show the place',
      type: 'number',
    }),
  },
  handler: async (connection, args, targeting) => {
    const options = { force: args.force, pid: args.pid };
    if (args.deployTarget !== undefined) {
      return closeDeployTargetAsync(connection, args.deployTarget, options);
    }

    const session = await connection
      .resolveSessionAsync(targeting.target, targeting.context)
      .catch(async (err: unknown) => {
        throw await explainMissingPlaytestContextAsync(connection, err);
      });
    return processCloseHandlerAsync(session, options, connection);
  },
});
