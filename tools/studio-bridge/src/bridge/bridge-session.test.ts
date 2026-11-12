/**
 * Unit tests for BridgeSession -- validates action delegation to
 * TransportHandle, disconnect error handling, and event forwarding.
 */

import { OutputHelper } from '@quenty/cli-output-helpers';
import { describe, it, expect, vi } from 'vitest';
import { EventEmitter } from 'events';
import { BridgeSession } from './bridge-session.js';
import { loadActionSourcesAsync } from '../commands/framework/action-loader.js';
import type { SessionInfo } from './types.js';
import {
  ActionTimeoutError,
  SessionDisconnectedError,
  STUDIO_BUSY_FIX,
} from './types.js';
import { StudioBridgeError } from '../messages/studio-bridge-error.js';
import { RequestTimeoutError } from '../server/pending-request-map.js';
import type {
  PluginMessage,
  ServerMessage,
} from '../server/web-socket-protocol.js';

// Mock loadActionSourcesAsync to return empty array so _ensureActionsAsync
// is a no-op in unit tests (no syncActions round-trip needed).
vi.mock('../commands/framework/action-loader.js', () => ({
  loadActionSourcesAsync: vi.fn(async () => []),
}));

class MockTransportHandle extends EventEmitter {
  private _isConnected: boolean;

  sendActionAsync = vi.fn(async () => ({})) as any;
  sendMessage = vi.fn();

  constructor(connected = true) {
    super();
    this._isConnected = connected;
  }

  get isConnected(): boolean {
    return this._isConnected;
  }

  simulateDisconnect(): void {
    this._isConnected = false;
    this.emit('disconnected');
  }

  simulateMessage(msg: PluginMessage): void {
    this.emit('message', msg);
  }
}

function createSessionInfo(overrides: Partial<SessionInfo> = {}): SessionInfo {
  return {
    sessionId: 'session-1',
    placeName: 'TestPlace',
    state: 'Edit',
    pluginVersion: '1.0.0',
    capabilities: ['execute', 'queryState'],
    connectedAt: new Date(),
    origin: 'user',
    context: 'edit',
    instanceId: 'inst-1',
    placeId: 123,
    gameId: 456,
    ...overrides,
  };
}

describe('BridgeSession', () => {
  describe('properties', () => {
    it('exposes session info', () => {
      const info = createSessionInfo({
        sessionId: 'my-session',
        context: 'server',
      });
      const handle = new MockTransportHandle();
      const session = new BridgeSession(info, handle);

      expect(session.info.sessionId).toBe('my-session');
      expect(session.context).toBe('server');
    });

    it('reflects connection state from handle', () => {
      const handle = new MockTransportHandle(true);
      const session = new BridgeSession(createSessionInfo(), handle);

      expect(session.isConnected).toBe(true);

      handle.simulateDisconnect();

      expect(session.isConnected).toBe(false);
    });
  });

  describe('disconnect handling', () => {
    it('emits disconnected event when handle disconnects', () => {
      const handle = new MockTransportHandle();
      const session = new BridgeSession(createSessionInfo(), handle);
      const listener = vi.fn();

      session.on('disconnected', listener);
      handle.simulateDisconnect();

      expect(listener).toHaveBeenCalledTimes(1);
    });

    it('throws SessionDisconnectedError when action called after disconnect', async () => {
      const handle = new MockTransportHandle(false);
      const session = new BridgeSession(
        createSessionInfo({ sessionId: 'disc-session' }),
        handle
      );

      await expect(session.execAsync('print("hi")')).rejects.toThrow(
        SessionDisconnectedError
      );
      await expect(session.queryStateAsync()).rejects.toThrow(
        SessionDisconnectedError
      );
      await expect(session.captureScreenshotAsync()).rejects.toThrow(
        SessionDisconnectedError
      );
      await expect(session.queryLogsAsync()).rejects.toThrow(
        SessionDisconnectedError
      );
      await expect(
        session.inspectInstanceAsync({ query: 'Workspace' })
      ).rejects.toThrow(SessionDisconnectedError);
    });
  });

  describe('execAsync', () => {
    it('delegates to handle.sendActionAsync with execute message', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'scriptComplete',
        sessionId: 'session-1',
        payload: { success: true },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      const result = await session.execAsync('print("hello")');

      expect(handle.sendActionAsync).toHaveBeenCalledTimes(1);
      const [msg, timeout] = handle.sendActionAsync.mock.calls[0];
      expect((msg as ServerMessage).type).toBe('execute');
      expect((msg as any).payload.script).toBe('print("hello")');
      expect((msg as any).payload.timeoutMs).toBe(120_000);
      expect(timeout).toBe(125_000);

      expect(result.success).toBe(true);
    });

    it('has the plugin cancel the script at a custom timeout, then waits for its reply', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'scriptComplete',
        sessionId: 'session-1',
        payload: { success: true },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      await session.execAsync('print("hello")', 5_000);

      const [msg, timeout] = handle.sendActionAsync.mock.calls[0];
      expect((msg as any).payload.timeoutMs).toBe(5_000);
      expect(timeout).toBe(10_000);
    });

    it('sends inputs base64-encoded', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'scriptComplete',
        sessionId: 'session-1',
        payload: { success: true },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      await session.execAsync('return ...', undefined, undefined, [
        Buffer.from('hello'),
      ]);

      const [msg] = handle.sendActionAsync.mock.calls[0];
      expect((msg as any).payload.inputs).toEqual(['aGVsbG8=']);
    });

    it('sends --run-as and carries back where the code ran', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'scriptComplete',
        sessionId: 'session-1',
        payload: { success: true, ranAs: 'game' },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      const result = await session.execAsync(
        'return 1',
        undefined,
        undefined,
        undefined,
        'game'
      );

      const [msg] = handle.sendActionAsync.mock.calls[0];
      expect((msg as any).payload.runAs).toBe('game');
      expect(result.ranAs).toBe('game');
    });

    it('refuses inputs over the size limit without sending them', async () => {
      const handle = new MockTransportHandle();
      const session = new BridgeSession(createSessionInfo(), handle);

      await expect(
        session.execAsync('return ...', undefined, undefined, [
          Buffer.alloc(192 * 1024 * 1024 + 1),
        ])
      ).rejects.toThrow('a script can be sent with.');
      expect(handle.sendActionAsync).not.toHaveBeenCalled();
    });

    it('returns error info from error response', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'error',
        sessionId: 'session-1',
        payload: { code: 'SCRIPT_RUNTIME_ERROR', message: 'boom' },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      const result = await session.execAsync('error("boom")');

      expect(result.success).toBe(false);
      expect(result.error).toBe('boom');
    });

    it('surfaces the values the script returned', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'scriptComplete',
        sessionId: 'session-1',
        payload: {
          success: true,
          returnValues: [{ counts: { passed: 3 } }, 42],
        },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      const result = await session.execAsync('return results, 42');

      expect(result.returnValues).toEqual([{ counts: { passed: 3 } }, 42]);
    });

    it('leaves returnValues undefined when the plugin reported none', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'scriptComplete',
        sessionId: 'session-1',
        payload: { success: true },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      const result = await session.execAsync('print("hello")');

      expect(result.returnValues).toBeUndefined();
    });

    it('leaves returnValues undefined on an error response', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'error',
        sessionId: 'session-1',
        payload: { code: 'SCRIPT_RUNTIME_ERROR', message: 'boom' },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      const result = await session.execAsync('error("boom")');

      expect(result.returnValues).toBeUndefined();
    });
  });

  describe('plugin errors', () => {
    async function queryStateErrorAsync(code: string): Promise<any> {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'error',
        sessionId: 'session-1',
        payload: { code, message: "Invalid query: Missing ')'" },
      });
      const session = new BridgeSession(createSessionInfo(), handle);
      return session.queryStateAsync().catch((err) => err);
    }

    it('shows an error in the request as its message alone, keeping the code', async () => {
      const err = await queryStateErrorAsync('INVALID_PAYLOAD');

      expect(err).toBeInstanceOf(StudioBridgeError);
      expect(err.message).toBe("Invalid query: Missing ')'.");
      expect(err.code).toBe('INVALID_PAYLOAD');
    });

    it('lists the instances that matched when one was needed', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'error',
        sessionId: 'session-1',
        payload: {
          code: 'INSTANCE_NOT_FOUND',
          message: "2 instances match --root 'Door', where one is needed",
          details: {
            matches: [
              {
                path: 'Workspace.Door',
                segments: ['Workspace', 'Door'],
                className: 'Part',
              },
              {
                path: 'Lighting.Door',
                segments: ['Lighting', 'Door'],
                className: 'Part',
              },
            ],
            total: 2,
          },
        },
      });
      const session = new BridgeSession(createSessionInfo(), handle);
      const err = await session
        .findInstancesAsync({ root: 'Door', query: 'x' })
        .catch((e) => e);

      expect(OutputHelper.stripAnsi(err.message)).toContain(
        "2 instances match --root 'Door', where one is needed:"
      );
      expect(OutputHelper.stripAnsi(err.message)).toContain('  Door (Part)');
      expect(err.code).toBe('INSTANCE_NOT_FOUND');
    });

    it('treats an internal plugin failure as a bug, not an expected error', async () => {
      const err = await queryStateErrorAsync('INTERNAL_ERROR');

      expect(err).not.toBeInstanceOf(StudioBridgeError);
      expect(err.message).toBe(
        "Studio failed running 'stateResult': Invalid query: Missing ')'"
      );
    });

    it('says the plugin is too old for a request it does not know', async () => {
      const err = await queryStateErrorAsync('UNKNOWN_REQUEST');

      expect(err).toMatchObject({
        code: 'PLUGIN_OUTDATED',
        fix: "Run 'studio-bridge plugin install'.",
      });
    });

    it('turns a timeout the host relays into one the user can act on', async () => {
      const err = await queryStateErrorAsync('TIMEOUT');

      expect(err).toBeInstanceOf(ActionTimeoutError);
      expect(err.message).toBe("Studio didn't reply within 5s.");
      expect(err.fix).toBe(STUDIO_BUSY_FIX);
    });

    it('turns a reply that never came into a timeout the user can act on', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockRejectedValueOnce(
        new RequestTimeoutError('a7c4e2b0-uuid', 5_000)
      );
      const session = new BridgeSession(createSessionInfo(), handle);

      const err = await session.queryStateAsync().catch((e) => e);

      expect(err).toMatchObject({
        code: 'TIMEOUT',
        message: "Studio didn't reply within 5s.",
        fix: STUDIO_BUSY_FIX,
      });
      expect(err.message).not.toContain('a7c4e2b0');
    });
  });

  describe('queryStateAsync', () => {
    it('returns state result from handle response', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'stateResult',
        sessionId: 'session-1',
        requestId: 'r-1',
        payload: {
          state: 'Play',
          placeId: 100,
          placeName: 'Test',
          gameId: 200,
        },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      const result = await session.queryStateAsync();

      expect(result.state).toBe('Play');
      expect(result.placeId).toBe(100);
      expect(result.placeName).toBe('Test');
      expect(result.gameId).toBe(200);
    });

    it('sends queryState message type', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'stateResult',
        sessionId: 'session-1',
        requestId: 'r-1',
        payload: { state: 'Edit', placeId: 0, placeName: 'Test', gameId: 0 },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      await session.queryStateAsync();

      const [msg] = handle.sendActionAsync.mock.calls[0];
      expect((msg as ServerMessage).type).toBe('queryState');
    });
  });

  describe('captureScreenshotAsync', () => {
    it('returns screenshot result', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'screenshotResult',
        sessionId: 'session-1',
        requestId: 'r-1',
        payload: { data: 'base64data', format: 'png', width: 800, height: 600 },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      const result = await session.captureScreenshotAsync();

      expect(result.data).toBe('base64data');
      expect(result.format).toBe('png');
      expect(result.width).toBe(800);
      expect(result.height).toBe(600);
    });
  });

  describe('queryLogsAsync', () => {
    it('returns logs result', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'logsResult',
        sessionId: 'session-1',
        requestId: 'r-1',
        payload: {
          entries: [{ level: 'Print', body: 'hello', timestamp: 12345 }],
          total: 1,
          bufferCapacity: 1000,
        },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      const result = await session.queryLogsAsync({
        count: 10,
        direction: 'tail',
      });

      expect(result.entries).toHaveLength(1);
      expect(result.total).toBe(1);
    });

    it('passes options to payload', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'logsResult',
        sessionId: 'session-1',
        requestId: 'r-1',
        payload: { entries: [], total: 0, bufferCapacity: 1000 },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      await session.queryLogsAsync({ count: 5, levels: ['Error', 'Warning'] });

      const [msg] = handle.sendActionAsync.mock.calls[0];
      expect((msg as any).payload.count).toBe(5);
      expect((msg as any).payload.levels).toEqual(['Error', 'Warning']);
    });
  });

  describe('inspectInstanceAsync', () => {
    it('returns the inspected instance', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'inspectInstanceResult',
        sessionId: 'session-1',
        requestId: 'r-1',
        payload: {
          instance: {
            name: 'Workspace',
            className: 'Workspace',
            path: 'game.Workspace',
            properties: [],
            attributes: [],
            childCount: 5,
          },
        },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      const result = await session.inspectInstanceAsync({
        query: 'Workspace',
      });

      expect(result.instance?.name).toBe('Workspace');
      expect(result.instance?.className).toBe('Workspace');
    });
  });

  describe('state change events', () => {
    it('emits state-changed and updates info on stateChange message', () => {
      const handle = new MockTransportHandle();
      const session = new BridgeSession(
        createSessionInfo({ state: 'Edit' }),
        handle
      );
      const listener = vi.fn();

      session.on('state-changed', listener);

      handle.simulateMessage({
        type: 'stateChange',
        sessionId: 'session-1',
        payload: {
          previousState: 'Edit',
          newState: 'Play',
          timestamp: Date.now(),
        },
      });

      expect(listener).toHaveBeenCalledWith('Play');
      expect(session.info.state).toBe('Play');
    });
  });

  describe('actions that fail to update', () => {
    it('warns once that a playtest runs an older version', async () => {
      vi.mocked(loadActionSourcesAsync).mockResolvedValueOnce([
        {
          name: 'query-state',
          source: '',
          relativePath: 'process/info/query-state.lua',
          hash: 'new',
        },
      ]);
      const handle = new MockTransportHandle();
      handle.sendActionAsync = vi.fn(async (message: ServerMessage) => {
        if (message.type === 'syncActions') {
          return {
            type: 'syncActionsResult',
            payload: { needed: ['query-state'] },
          };
        }
        if (message.type === 'registerAction') {
          return {
            type: 'registerActionResult',
            payload: {
              name: 'query-state',
              success: false,
              outdated: true,
              handlers: ['queryState'],
            },
          };
        }
        return { type: 'stateResult', payload: { state: 'Play' } };
      }) as any;
      const warn = vi.spyOn(OutputHelper, 'warn').mockImplementation(() => {});
      const session = new BridgeSession(
        createSessionInfo({ context: 'server' }),
        handle
      );

      await session.queryStateAsync();
      await session.queryStateAsync();

      expect(warn.mock.calls).toEqual([
        [
          "This playtest runs an older 'process info', so it may not do what this version does.",
        ],
      ]);
      warn.mockRestore();
    });

    it('does not push again a hash the plugin already failed to install', async () => {
      vi.mocked(loadActionSourcesAsync).mockResolvedValueOnce([
        {
          name: 'query-state',
          source: '',
          relativePath: 'process/info/query-state.lua',
          hash: 'new',
        },
      ]);
      const handle = new MockTransportHandle();
      const sent: string[] = [];
      handle.sendActionAsync = vi.fn(async (message: ServerMessage) => {
        sent.push(message.type);
        if (message.type === 'syncActions') {
          return {
            type: 'syncActionsResult',
            payload: {
              needed: [],
              installed: { 'query-state': 'old' },
              failed: {
                'query-state': { error: 'boom', handlers: ['queryState'] },
              },
            },
          };
        }
        return { type: 'stateResult', payload: { state: 'Edit' } };
      }) as any;
      const warn = vi.spyOn(OutputHelper, 'warn').mockImplementation(() => {});
      const session = new BridgeSession(createSessionInfo(), handle);

      await session.queryStateAsync();

      expect(sent).toEqual(['syncActions', 'queryState']);
      expect(warn.mock.calls).toEqual([
        [
          "Studio runs an older 'process info', since the update failed to load, so it may not do what this version does.",
        ],
      ]);
      warn.mockRestore();
    });
  });
});
