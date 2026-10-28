import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('../../../process/studio-process-closer.js', async (importOriginal) => {
  const actual = await importOriginal<
    typeof import('../../../process/studio-process-closer.js')
  >();
  return {
    ...actual,
    listStudioProcessesAsync: vi.fn(),
    closeStudioProcessAsync: vi.fn(),
  };
});

import { processCloseHandlerAsync } from './close.js';
import {
  closeStudioProcessAsync,
  listStudioProcessesAsync,
} from '../../../process/studio-process-closer.js';

const queryStateAsync = async () => ({ placeId: 0 });

const session = {
  info: { sessionId: 'test-place-edit', placeName: 'test-place.rbxl' },
  queryStateAsync,
} as any;

describe('processCloseHandlerAsync', () => {
  beforeEach(() => {
    vi.mocked(listStudioProcessesAsync).mockResolvedValue([
      { pid: 10, windowTitle: 'C:\\places\\test-place.rbxl - Roblox Studio' },
      { pid: 20, windowTitle: 'Other - Roblox Studio' },
    ]);
    vi.mocked(closeStudioProcessAsync).mockReset().mockResolvedValue(true);
  });

  it('closes the Studio window showing the session place', async () => {
    const result = await processCloseHandlerAsync(session);

    expect(closeStudioProcessAsync).toHaveBeenCalledWith(10, {
      force: undefined,
    });
    expect(result).toMatchObject({ success: true, pid: 10 });
  });

  it('closes the Studio a single-process playtest runs in', async () => {
    const server = {
      info: {
        sessionId: 'test-place-server',
        instanceId: 'test-place',
        context: 'server',
        placeName: 'Game',
      },
      queryStateAsync,
    } as any;
    const connection = {
      listSessions: () => [
        {
          sessionId: 'test-place-server',
          instanceId: 'test-place',
          context: 'server',
          placeName: 'test-place.rbxl',
        },
      ],
    } as any;

    const result = await processCloseHandlerAsync(server, {}, connection);

    expect(result).toMatchObject({ success: true, pid: 10 });
  });

  it('refuses a multiplayer test process without --pid', async () => {
    const client = {
      info: {
        sessionId: 'test-place-client-player1',
        instanceId: 'test-place',
        context: 'client',
        placeName: 'Game',
      },
      queryStateAsync,
    } as any;
    const connection = {
      listSessions: () =>
        ['player1', 'player2'].map((player) => ({
          sessionId: `test-place-client-${player}`,
          instanceId: 'test-place',
          context: 'client',
          placeName: 'test-place.rbxl',
          playerName: player,
        })),
    } as any;

    const result = await processCloseHandlerAsync(client, {}, connection);

    expect(result.success).toBe(false);
    expect(result.summary).toContain("'studio-bridge playtest stop'");
    expect(closeStudioProcessAsync).not.toHaveBeenCalled();
  });

  it('finds a cloud place by the place id Studio was launched with', async () => {
    vi.mocked(listStudioProcessesAsync).mockResolvedValue([
      {
        pid: 30,
        windowTitle: 'My Game (abc123) - Roblox Studio',
        commandLine:
          'RobloxStudioBeta.exe roblox-studio:1+placeId:555+universeId:9',
      },
    ]);
    const cloudSession = {
      info: { sessionId: 'place1-edit', placeName: 'Place1', placeId: 0 },
      queryStateAsync: async () => ({ placeId: 555 }),
    } as any;

    const result = await processCloseHandlerAsync(cloudSession);

    expect(result).toMatchObject({ success: true, pid: 30 });
  });

  it('passes --force through', async () => {
    await processCloseHandlerAsync(session, { force: true });

    expect(closeStudioProcessAsync).toHaveBeenCalledWith(10, { force: true });
  });

  it('suggests --force when Studio stays open', async () => {
    vi.mocked(closeStudioProcessAsync).mockResolvedValue(false);

    const result = await processCloseHandlerAsync(session);

    expect(result.success).toBe(false);
    expect(result.summary).toContain('--force');
  });

  it('fails without closing when no window shows the place', async () => {
    vi.mocked(listStudioProcessesAsync).mockResolvedValue([
      { pid: 20, windowTitle: 'Other - Roblox Studio' },
    ]);

    const result = await processCloseHandlerAsync(session);

    expect(result.success).toBe(false);
    expect(closeStudioProcessAsync).not.toHaveBeenCalled();
  });

  it('asks for --pid when several windows show the place', async () => {
    vi.mocked(listStudioProcessesAsync).mockResolvedValue([
      { pid: 10, windowTitle: 'C:\\a\\test-place.rbxl - Roblox Studio' },
      { pid: 11, windowTitle: 'C:\\b\\test-place.rbxl - Roblox Studio' },
    ]);

    const result = await processCloseHandlerAsync(session);

    expect(result.success).toBe(false);
    expect(result.summary).toContain('--pid');
    expect(closeStudioProcessAsync).not.toHaveBeenCalled();
  });

  it('closes the process picked with --pid', async () => {
    const result = await processCloseHandlerAsync(session, { pid: 20 });

    expect(closeStudioProcessAsync).toHaveBeenCalledWith(20, {
      force: undefined,
    });
    expect(result.success).toBe(true);
  });
});
