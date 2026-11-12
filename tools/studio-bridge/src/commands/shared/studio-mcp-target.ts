import type { BridgeConnection, BridgeSession } from '../../bridge/index.js';
import type { StudioMcpOptions } from '../../roblox-mcp/index.js';
import { listStudioProcessesAsync } from '../../process/studio-process-closer.js';
import { resolveSessionPidsAsync } from '../../process/studio-process-identity.js';

export async function resolveStudioMcpTargetAsync(
  session: BridgeSession,
  connection?: BridgeConnection
): Promise<StudioMcpOptions> {
  const processes = connection
    ? await listStudioProcessesAsync().catch(() => [])
    : [];
  const sessionPids =
    connection && processes.length > 0
      ? await resolveSessionPidsAsync(connection, processes, [
          session.info.instanceId,
        ])
      : undefined;
  return {
    target: session.info.instanceId,
    sessions: connection?.listSessions() ?? [session.info],
    ...(sessionPids ? { sessionPids } : {}),
    ...(processes.length > 0
      ? { listWindowsAsync: async () => processes }
      : {}),
  };
}
