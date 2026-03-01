/**
 * Unit tests for BridgeSession -- validates action delegation to
 * TransportHandle, disconnect error handling, and event forwarding.
 */

import { describe, it, expect, vi } from 'vitest';
import { EventEmitter } from 'events';
import { BridgeSession } from './bridge-session.js';
import type { SessionInfo } from './types.js';
import { SessionDisconnectedError } from './types.js';
import type { PluginMessage, ServerMessage } from '../server/web-socket-protocol.js';

// Mock loadActionSourcesAsync to return empty array so _ensureActionsAsync
// is a no-op in unit tests (no syncActions round-trip needed).
vi.mock('../commands/framework/action-loader.js', () => ({
  loadActionSourcesAsync: vi.fn(async () => []),
}));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('BridgeSession', () => {
  // -----------------------------------------------------------------------
  // Properties
  // -----------------------------------------------------------------------

  describe('properties', () => {
    it('exposes session info', () => {
      const info = createSessionInfo({ sessionId: 'my-session', context: 'server' });
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

  // -----------------------------------------------------------------------
  // Disconnect handling
  // -----------------------------------------------------------------------

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
        handle,
      );

      await expect(session.execAsync('print("hi")')).rejects.toThrow(SessionDisconnectedError);
      await expect(session.queryStateAsync()).rejects.toThrow(SessionDisconnectedError);
      await expect(session.captureScreenshotAsync()).rejects.toThrow(SessionDisconnectedError);
      await expect(session.queryLogsAsync()).rejects.toThrow(SessionDisconnectedError);
      await expect(
        session.queryDataModelAsync({ path: 'game' }),
      ).rejects.toThrow(SessionDisconnectedError);
      await expect(
        session.subscribeAsync(['stateChange']),
      ).rejects.toThrow(SessionDisconnectedError);
      await expect(
        session.unsubscribeAsync(['stateChange']),
      ).rejects.toThrow(SessionDisconnectedError);
    });
  });

  // -----------------------------------------------------------------------
  // Action: execAsync
  // -----------------------------------------------------------------------

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
      expect(timeout).toBe(120_000);

      expect(result.success).toBe(true);
    });

    it('uses custom timeout when provided', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'scriptComplete',
        sessionId: 'session-1',
        payload: { success: true },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      await session.execAsync('print("hello")', 5_000);

      const [, timeout] = handle.sendActionAsync.mock.calls[0];
      expect(timeout).toBe(5_000);
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
  });

  // -----------------------------------------------------------------------
  // Action: queryStateAsync
  // -----------------------------------------------------------------------

  describe('queryStateAsync', () => {
    it('returns state result from handle response', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'stateResult',
        sessionId: 'session-1',
        requestId: 'r-1',
        payload: { state: 'Play', placeId: 100, placeName: 'Test', gameId: 200 },
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

  // -----------------------------------------------------------------------
  // Action: captureScreenshotAsync
  // -----------------------------------------------------------------------

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

  // -----------------------------------------------------------------------
  // Action: queryLogsAsync
  // -----------------------------------------------------------------------

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
      const result = await session.queryLogsAsync({ count: 10, direction: 'tail' });

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

  // -----------------------------------------------------------------------
  // Action: queryDataModelAsync
  // -----------------------------------------------------------------------

  describe('queryDataModelAsync', () => {
    it('returns data model result', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'dataModelResult',
        sessionId: 'session-1',
        requestId: 'r-1',
        payload: {
          instance: {
            name: 'Workspace',
            className: 'Workspace',
            path: 'game.Workspace',
            properties: {},
            attributes: {},
            childCount: 5,
          },
        },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      const result = await session.queryDataModelAsync({ path: 'game.Workspace' });

      expect(result.instance.name).toBe('Workspace');
      expect(result.instance.className).toBe('Workspace');
    });
  });

  // -----------------------------------------------------------------------
  // Action: subscribeAsync / unsubscribeAsync
  // -----------------------------------------------------------------------

  describe('subscribeAsync', () => {
    it('sends subscribe message', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'subscribeResult',
        sessionId: 'session-1',
        requestId: 'r-1',
        payload: { events: ['stateChange'] },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      await session.subscribeAsync(['stateChange']);

      const [msg] = handle.sendActionAsync.mock.calls[0];
      expect((msg as ServerMessage).type).toBe('subscribe');
      expect((msg as any).payload.events).toEqual(['stateChange']);
    });
  });

  describe('unsubscribeAsync', () => {
    it('sends unsubscribe message', async () => {
      const handle = new MockTransportHandle();
      handle.sendActionAsync.mockResolvedValueOnce({
        type: 'unsubscribeResult',
        sessionId: 'session-1',
        requestId: 'r-1',
        payload: { events: ['stateChange'] },
      });

      const session = new BridgeSession(createSessionInfo(), handle);
      await session.unsubscribeAsync(['stateChange']);

      const [msg] = handle.sendActionAsync.mock.calls[0];
      expect((msg as ServerMessage).type).toBe('unsubscribe');
    });
  });

  // -----------------------------------------------------------------------
  // State change events
  // -----------------------------------------------------------------------

  describe('state change events', () => {
    it('emits state-changed and updates info on stateChange message', () => {
      const handle = new MockTransportHandle();
      const session = new BridgeSession(
        createSessionInfo({ state: 'Edit' }),
        handle,
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
});
