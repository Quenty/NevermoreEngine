/**
 * `process close` — close the Studio process a session belongs to.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeConnection, BridgeSession } from '../../../bridge/index.js';
import {
  closeStudioProcessAsync,
  listStudioProcessesAsync,
  matchStudioProcesses,
} from '../../../process/studio-process-closer.js';
import { describePlaytest } from '../info/info.js';

export interface ProcessCloseResult {
  success: boolean;
  sessionId: string;
  pid?: number;
  summary: string;
}

export interface ProcessCloseOptions {
  force?: boolean;
  pid?: number;
}

interface ProcessCloseArgs {
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
  const fail = (summary: string, pid?: number): ProcessCloseResult => ({
    success: false,
    sessionId,
    pid,
    summary,
  });

  const isMultiplayerProcess =
    context !== 'edit' &&
    describePlaytest(sessions, instanceId)?.playerCount !== undefined;
  if (isMultiplayerProcess && options.pid === undefined) {
    return fail(
      `'${sessionId}' runs in its own process of a multiplayer test. End the test with 'studio-bridge playtest stop', remove a player with 'studio-bridge playtest player remove', or pass --pid.`
    );
  }

  const processes = await listStudioProcessesAsync();
  const candidates =
    options.pid !== undefined
      ? processes.filter((proc) => proc.pid === options.pid)
      : matchStudioProcesses(processes, placeName);

  if (candidates.length === 0) {
    return fail(
      options.pid !== undefined
        ? `No Studio process with pid ${options.pid}`
        : `No Studio window is showing '${placeName}'`
    );
  }

  if (candidates.length > 1) {
    const pids = candidates.map((proc) => proc.pid).join(', ');
    return fail(
      `${candidates.length} Studio windows are showing '${placeName}' (pids ${pids}). Pick one with --pid.`
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
    success: true,
    sessionId,
    pid,
    summary: `Closed Studio (pid ${pid}) showing '${placeName}'`,
  };
}

export const processCloseCommand = defineCommand<
  ProcessCloseArgs,
  ProcessCloseResult
>({
  group: 'process',
  name: 'close',
  description: 'Close the Studio process a session belongs to',
  category: 'infrastructure',
  safety: 'mutate',
  scope: 'session',
  args: {
    force: arg.flag({
      description: 'Kill Studio without letting it prompt to save',
      alias: 'f',
    }),
    pid: arg.option({
      description: 'Studio process id, when several windows show the place',
      type: 'number',
    }),
  },
  handler: async (session, args, connection) =>
    processCloseHandlerAsync(
      session,
      { force: args.force, pid: args.pid },
      connection
    ),
});
