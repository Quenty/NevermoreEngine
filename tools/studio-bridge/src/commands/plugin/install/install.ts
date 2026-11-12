import { defineCommand } from '../../framework/define-command.js';
import { BridgeConnection } from '../../../bridge/index.js';
import type { SessionInfo } from '../../../bridge/index.js';
import { installPersistentPluginAsync } from '../../../plugin/persistent-plugin-installer.js';
import { getPluginBuildVersionAsync } from '../../../plugin/plugin-build-version.js';
import {
  formatPluginVersion,
  PLUGIN_RELOAD_TIMEOUT_MS,
  waitForPluginReloadAsync,
} from '../../../cli/plugin-freshness.js';
import { reportStaleHost } from '../../../cli/cli-output-context.js';

/** What happened in one connected Studio. */
export type PluginReloadStatus = 'current' | 'reloaded' | 'not-reloaded';

export interface InstallPluginResult {
  path: string;
  version: string;
  sessions: Array<{
    sessionId: string;
    placeName: string;
    status: PluginReloadStatus;
  }>;
  remote?: boolean;
  summary: string;
}

export interface InstallPluginDeps {
  installAsync: () => Promise<string>;
  getVersionAsync: () => Promise<string>;
  connectAsync: () => Promise<BridgeConnection>;
  reloadTimeoutMs: number;
}

const defaultDeps: InstallPluginDeps = {
  installAsync: installPersistentPluginAsync,
  getVersionAsync: getPluginBuildVersionAsync,
  connectAsync: () =>
    BridgeConnection.connectAsync({ local: true, waitForSessions: true }),
  reloadTimeoutMs: PLUGIN_RELOAD_TIMEOUT_MS,
};

export async function installPluginHandlerAsync(
  overrides: Partial<InstallPluginDeps> = {}
): Promise<InstallPluginResult> {
  const deps = { ...defaultDeps, ...overrides };
  const version = await deps.getVersionAsync();

  const connection = await deps.connectAsync();
  reportStaleHost(connection);
  try {
    const studios = connection
      .listSessions()
      .filter((info) => info.context === 'edit');
    const installedPath = await deps.installAsync();
    const stale = studios.filter((info) => info.pluginVersion !== version);
    const reloads = connection.isRemote
      ? []
      : await waitForPluginReloadAsync(
          connection,
          stale,
          version,
          deps.reloadTimeoutMs
        );

    const sessions = connection.isRemote
      ? []
      : studios.map((info) => ({
          sessionId: info.sessionId,
          placeName: info.placeName,
          status: statusOf(info, version, reloads),
        }));
    const result: Omit<InstallPluginResult, 'summary'> = {
      path: installedPath,
      version,
      sessions,
      ...(connection.isRemote ? { remote: true } : {}),
    };
    return {
      ...result,
      summary: formatInstallSummary(result, deps.reloadTimeoutMs),
    };
  } finally {
    await connection.disconnectAsync();
  }
}

function statusOf(
  info: SessionInfo,
  version: string,
  reloads: Array<{ sessionId: string; session?: unknown }>
): PluginReloadStatus {
  if (info.pluginVersion === version) return 'current';
  const reload = reloads.find((r) => r.sessionId === info.sessionId);
  return reload?.session ? 'reloaded' : 'not-reloaded';
}

export function formatInstallSummary(
  result: Omit<InstallPluginResult, 'summary'>,
  reloadTimeoutMs: number
): string {
  const lines = [
    `Installed studio-bridge plugin ${formatPluginVersion(result.version)}.`,
  ];
  if (result.remote) {
    lines.push(
      "  Studio runs on the bridge host's machine; this installed it on this one."
    );
  }
  for (const session of result.sessions) {
    if (session.status === 'current') {
      lines.push(`  ✓ ${session.placeName} already had it`);
    } else if (session.status === 'reloaded') {
      lines.push(`  ✓ ${session.placeName} reloaded`);
    } else {
      lines.push(
        `  ✗ ${session.placeName} did not reload within ${
          reloadTimeoutMs / 1000
        }s; reopen it in Studio to load the new plugin`
      );
    }
  }
  return lines.join('\n');
}

export const installCommand = defineCommand({
  group: 'plugin',
  name: 'install',
  description:
    'Install the persistent Studio Bridge plugin, and wait for open Studios to reload it',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {},
  handler: async () => installPluginHandlerAsync(),
});
