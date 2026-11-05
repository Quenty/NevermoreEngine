import type { BridgeConnection, SessionInfo } from '../bridge/index.js';
import type { RunningStudioProcess } from './studio-process-closer.js';

export const UPTIME_TOLERANCE_MS = 3000;
const UPTIME_DRIFT_RATIO = 0.0025;
const UPTIME_READ_TIMEOUT_MS = 3000;

export interface UptimeReading {
  uptimeSec: number;
  observedAt: number;
}

export function matchProcessByUptime<
  T extends Pick<RunningStudioProcess, 'pid' | 'startedAt'>
>(processes: T[], reading: UptimeReading): T | undefined {
  const startedAt = reading.observedAt - reading.uptimeSec * 1000;
  const tolerance =
    UPTIME_TOLERANCE_MS + reading.uptimeSec * 1000 * UPTIME_DRIFT_RATIO;
  const candidates = processes
    .filter((p) => p.startedAt !== undefined)
    .map((p) => ({ process: p, delta: Math.abs(p.startedAt! - startedAt) }))
    .sort((a, b) => a.delta - b.delta);
  const [best, next] = candidates;
  if (!best || best.delta > tolerance) {
    return undefined;
  }
  if (next && next.delta <= tolerance) {
    return undefined;
  }
  return best.process;
}

export async function resolveSessionPidsAsync(
  connection: BridgeConnection,
  processes: RunningStudioProcess[],
  instanceIds?: string[]
): Promise<Map<string, number>> {
  const pids = new Map<string, number>();
  if (!processes.some((p) => p.startedAt !== undefined)) {
    return pids;
  }

  const byInstance = new Map<string, SessionInfo[]>();
  for (const session of connection.listSessions()) {
    if (instanceIds && !instanceIds.includes(session.instanceId)) continue;
    const list = byInstance.get(session.instanceId) ?? [];
    list.push(session);
    byInstance.set(session.instanceId, list);
  }

  await Promise.all(
    [...byInstance].map(async ([instanceId, sessions]) => {
      const ordered = [...sessions].sort(
        (a, b) => Number(b.context === 'edit') - Number(a.context === 'edit')
      );
      for (const info of ordered) {
        const reading = await _readUptimeAsync(connection, info.sessionId);
        if (reading) {
          const match = matchProcessByUptime(processes, reading);
          if (match) {
            pids.set(instanceId, match.pid);
          }
          return;
        }
      }
    })
  );
  return pids;
}

async function _readUptimeAsync(
  connection: BridgeConnection,
  sessionId: string
): Promise<UptimeReading | undefined> {
  try {
    const session = await connection.resolveSessionAsync(sessionId);
    const sentAt = Date.now();
    const result = await session.execAsync(
      'return os.clock()',
      UPTIME_READ_TIMEOUT_MS
    );
    const uptimeSec = Number(result.returnValues?.[0]);
    if (!result.success || !Number.isFinite(uptimeSec)) {
      return undefined;
    }
    return { uptimeSec, observedAt: (sentAt + Date.now()) / 2 };
  } catch {
    return undefined;
  }
}
