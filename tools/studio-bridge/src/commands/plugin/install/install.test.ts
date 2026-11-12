import { describe, it, expect, vi } from 'vitest';
import { installPluginHandlerAsync } from './install.js';

function info(placeName: string, pluginVersion: string, context = 'edit') {
  return {
    sessionId: `${placeName.toLowerCase()}-edit`,
    instanceId: placeName.toLowerCase(),
    placeName,
    context,
    pluginVersion,
  };
}

describe('installPluginHandlerAsync', () => {
  it('reports which connected Studios reloaded the new plugin', async () => {
    let live = [
      info('MapNotifications', 'old000000000'),
      info('Place1', 'old000000000'),
      info('Current', 'c3d4e5f6a7b8'),
      info('Playtest', 'old000000000', 'server'),
    ];
    const connection = {
      isRemote: false,
      listSessions: () => live,
      getSession: (id: string) => {
        const found = live.find((s) => s.sessionId === id);
        return found && { info: found };
      },
      disconnectAsync: vi.fn(async () => {}),
    };

    const result = await installPluginHandlerAsync({
      getVersionAsync: async () => 'c3d4e5f6a7b8',
      connectAsync: async () => connection as any,
      installAsync: async () => {
        live = live.map((s) =>
          s.placeName === 'MapNotifications'
            ? { ...s, pluginVersion: 'c3d4e5f6a7b8' }
            : s
        );
        return 'C:/Plugins/StudioBridgePersistentPlugin.rbxm';
      },
      reloadTimeoutMs: 300,
    });

    expect(result.sessions).toEqual([
      {
        sessionId: 'mapnotifications-edit',
        placeName: 'MapNotifications',
        status: 'reloaded',
      },
      { sessionId: 'place1-edit', placeName: 'Place1', status: 'not-reloaded' },
      { sessionId: 'current-edit', placeName: 'Current', status: 'current' },
    ]);
    expect(result.summary).toBe(
      [
        'Installed studio-bridge plugin c3d4e5.',
        '  ✓ MapNotifications reloaded',
        '  ✗ Place1 did not reload within 0.3s; reopen it in Studio to load the new plugin',
        '  ✓ Current already had it',
      ].join('\n')
    );
    expect(connection.disconnectAsync).toHaveBeenCalled();
  });
});
