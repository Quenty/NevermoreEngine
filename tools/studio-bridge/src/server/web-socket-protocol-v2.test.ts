import { describe, it, expect } from 'vitest';
import {
  encodeMessage,
  decodePluginMessage,
  decodeServerMessage,
  type PluginMessage,
  type ServerMessage,
} from './web-socket-protocol.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Encode a plugin message, decode it, and return the result. */
function roundTripPlugin(msg: Record<string, unknown>): PluginMessage | null {
  return decodePluginMessage(JSON.stringify(msg));
}

/** Encode a server message via encodeMessage, decode it, and return the result. */
function roundTripServer(msg: ServerMessage): ServerMessage | null {
  return decodeServerMessage(encodeMessage(msg));
}

// ---------------------------------------------------------------------------
// v2 Plugin → Server messages
// ---------------------------------------------------------------------------

describe('decodePluginMessage (v2)', () => {
  describe('hello (v2 extensions)', () => {
    it('decodes hello with pluginVersion and capabilities', () => {
      const msg = roundTripPlugin({
        type: 'hello',
        sessionId: 'sess-1',
        payload: {
          sessionId: 'sess-1',
          pluginVersion: '2.0.0',
          capabilities: ['execute', 'queryState'],
        },
      });
      expect(msg).toEqual({
        type: 'hello',
        sessionId: 'sess-1',
        payload: {
          sessionId: 'sess-1',
          pluginVersion: '2.0.0',
          capabilities: ['execute', 'queryState'],
        },
      });
    });

    it('decodes hello without v2 fields (backward compat)', () => {
      const msg = roundTripPlugin({
        type: 'hello',
        sessionId: 'sess-1',
        payload: { sessionId: 'sess-1' },
      });
      expect(msg).toEqual({
        type: 'hello',
        sessionId: 'sess-1',
        payload: {
          sessionId: 'sess-1',
          pluginVersion: undefined,
          capabilities: undefined,
        },
      });
    });
  });

  describe('scriptComplete (v2 requestId)', () => {
    it('decodes scriptComplete with requestId', () => {
      const msg = roundTripPlugin({
        type: 'scriptComplete',
        sessionId: 'sess-1',
        requestId: 'req-42',
        payload: { success: true },
      });
      expect(msg).toEqual({
        type: 'scriptComplete',
        sessionId: 'sess-1',
        requestId: 'req-42',
        payload: { success: true, error: undefined },
      });
    });

    it('decodes scriptComplete without requestId (v1 compat)', () => {
      const msg = roundTripPlugin({
        type: 'scriptComplete',
        sessionId: 'sess-1',
        payload: { success: false, error: 'oops' },
      });
      expect(msg).toEqual({
        type: 'scriptComplete',
        sessionId: 'sess-1',
        payload: { success: false, error: 'oops' },
      });
      expect(msg).not.toHaveProperty('requestId');
    });
  });

  describe('register', () => {
    const validRegister = {
      type: 'register',
      sessionId: 'sess-1',
      protocolVersion: 2,
      payload: {
        pluginVersion: '2.0.0',
        instanceId: 'inst-abc',
        placeName: 'TestPlace',
        state: 'Edit',
        capabilities: ['execute', 'queryState'],
      },
    };

    it('decodes a valid register message', () => {
      const msg = roundTripPlugin(validRegister);
      expect(msg).toEqual({
        type: 'register',
        sessionId: 'sess-1',
        protocolVersion: 2,
        payload: {
          pluginVersion: '2.0.0',
          instanceId: 'inst-abc',
          placeName: 'TestPlace',
          placeFile: undefined,
          state: 'Edit',
          pid: undefined,
          capabilities: ['execute', 'queryState'],
        },
      });
    });

    it('decodes register with optional fields', () => {
      const msg = roundTripPlugin({
        ...validRegister,
        payload: {
          ...validRegister.payload,
          placeFile: 'TestPlace.rbxl',
          pid: 12345,
        },
      });
      expect(msg).not.toBeNull();
      expect((msg as any).payload.placeFile).toBe('TestPlace.rbxl');
      expect((msg as any).payload.pid).toBe(12345);
    });

    it('returns null when protocolVersion is missing', () => {
      const { protocolVersion: _, ...noVersion } = validRegister;
      expect(roundTripPlugin(noVersion)).toBeNull();
    });

    it('returns null when required payload field is missing', () => {
      const broken = {
        ...validRegister,
        payload: { pluginVersion: '2.0.0' },
      };
      expect(roundTripPlugin(broken)).toBeNull();
    });
  });

  describe('stateResult', () => {
    it('decodes a valid stateResult', () => {
      const msg = roundTripPlugin({
        type: 'stateResult',
        sessionId: 'sess-1',
        requestId: 'req-1',
        payload: { state: 'Play', placeId: 123, placeName: 'MyPlace', gameId: 456 },
      });
      expect(msg).toEqual({
        type: 'stateResult',
        sessionId: 'sess-1',
        requestId: 'req-1',
        payload: { state: 'Play', placeId: 123, placeName: 'MyPlace', gameId: 456 },
      });
    });

    it('returns null without requestId', () => {
      expect(roundTripPlugin({
        type: 'stateResult',
        sessionId: 'sess-1',
        payload: { state: 'Play', placeId: 123, placeName: 'MyPlace', gameId: 456 },
      })).toBeNull();
    });

    it('returns null with missing payload fields', () => {
      expect(roundTripPlugin({
        type: 'stateResult',
        sessionId: 'sess-1',
        requestId: 'req-1',
        payload: { state: 'Play' },
      })).toBeNull();
    });
  });

  describe('screenshotResult', () => {
    it('decodes a valid screenshotResult', () => {
      const msg = roundTripPlugin({
        type: 'screenshotResult',
        sessionId: 'sess-1',
        requestId: 'req-2',
        payload: { data: 'base64data', format: 'png', width: 1920, height: 1080 },
      });
      expect(msg).toEqual({
        type: 'screenshotResult',
        sessionId: 'sess-1',
        requestId: 'req-2',
        payload: { data: 'base64data', format: 'png', width: 1920, height: 1080 },
      });
    });

    it('returns null without requestId', () => {
      expect(roundTripPlugin({
        type: 'screenshotResult',
        sessionId: 'sess-1',
        payload: { data: 'base64data', format: 'png', width: 1920, height: 1080 },
      })).toBeNull();
    });

    it('returns null with wrong format', () => {
      expect(roundTripPlugin({
        type: 'screenshotResult',
        sessionId: 'sess-1',
        requestId: 'req-2',
        payload: { data: 'base64data', format: 'jpeg', width: 1920, height: 1080 },
      })).toBeNull();
    });
  });

  describe('dataModelResult', () => {
    const instance = {
      name: 'Workspace',
      className: 'Workspace',
      path: 'game.Workspace',
      properties: {},
      attributes: {},
      childCount: 3,
      children: [],
    };

    it('decodes a valid dataModelResult', () => {
      const msg = roundTripPlugin({
        type: 'dataModelResult',
        sessionId: 'sess-1',
        requestId: 'req-3',
        payload: { instance },
      });
      expect(msg).toEqual({
        type: 'dataModelResult',
        sessionId: 'sess-1',
        requestId: 'req-3',
        payload: { instance },
      });
    });

    it('returns null without requestId', () => {
      expect(roundTripPlugin({
        type: 'dataModelResult',
        sessionId: 'sess-1',
        payload: { instance },
      })).toBeNull();
    });

    it('returns null when instance is not an object', () => {
      expect(roundTripPlugin({
        type: 'dataModelResult',
        sessionId: 'sess-1',
        requestId: 'req-3',
        payload: { instance: 'not-an-object' },
      })).toBeNull();
    });
  });

  describe('logsResult', () => {
    it('decodes a valid logsResult', () => {
      const msg = roundTripPlugin({
        type: 'logsResult',
        sessionId: 'sess-1',
        requestId: 'req-4',
        payload: {
          entries: [{ level: 'Print', body: 'Hello', timestamp: 1000 }],
          total: 1,
          bufferCapacity: 1000,
        },
      });
      expect(msg).toEqual({
        type: 'logsResult',
        sessionId: 'sess-1',
        requestId: 'req-4',
        payload: {
          entries: [{ level: 'Print', body: 'Hello', timestamp: 1000 }],
          total: 1,
          bufferCapacity: 1000,
        },
      });
    });

    it('returns null without requestId', () => {
      expect(roundTripPlugin({
        type: 'logsResult',
        sessionId: 'sess-1',
        payload: { entries: [], total: 0, bufferCapacity: 1000 },
      })).toBeNull();
    });

    it('returns null with missing total', () => {
      expect(roundTripPlugin({
        type: 'logsResult',
        sessionId: 'sess-1',
        requestId: 'req-4',
        payload: { entries: [], bufferCapacity: 1000 },
      })).toBeNull();
    });
  });

  describe('stateChange', () => {
    it('decodes a valid stateChange', () => {
      const msg = roundTripPlugin({
        type: 'stateChange',
        sessionId: 'sess-1',
        payload: { previousState: 'Edit', newState: 'Play', timestamp: 12345 },
      });
      expect(msg).toEqual({
        type: 'stateChange',
        sessionId: 'sess-1',
        payload: { previousState: 'Edit', newState: 'Play', timestamp: 12345 },
      });
    });

    it('returns null with missing timestamp', () => {
      expect(roundTripPlugin({
        type: 'stateChange',
        sessionId: 'sess-1',
        payload: { previousState: 'Edit', newState: 'Play' },
      })).toBeNull();
    });
  });

  describe('heartbeat', () => {
    it('decodes a valid heartbeat', () => {
      const msg = roundTripPlugin({
        type: 'heartbeat',
        sessionId: 'sess-1',
        payload: { uptimeMs: 60000, state: 'Edit', pendingRequests: 0 },
      });
      expect(msg).toEqual({
        type: 'heartbeat',
        sessionId: 'sess-1',
        payload: { uptimeMs: 60000, state: 'Edit', pendingRequests: 0 },
      });
    });

    it('returns null with missing pendingRequests', () => {
      expect(roundTripPlugin({
        type: 'heartbeat',
        sessionId: 'sess-1',
        payload: { uptimeMs: 60000, state: 'Edit' },
      })).toBeNull();
    });
  });

  describe('subscribeResult', () => {
    it('decodes a valid subscribeResult', () => {
      const msg = roundTripPlugin({
        type: 'subscribeResult',
        sessionId: 'sess-1',
        requestId: 'req-5',
        payload: { events: ['stateChange', 'logPush'] },
      });
      expect(msg).toEqual({
        type: 'subscribeResult',
        sessionId: 'sess-1',
        requestId: 'req-5',
        payload: { events: ['stateChange', 'logPush'] },
      });
    });

    it('returns null without requestId', () => {
      expect(roundTripPlugin({
        type: 'subscribeResult',
        sessionId: 'sess-1',
        payload: { events: ['stateChange'] },
      })).toBeNull();
    });
  });

  describe('unsubscribeResult', () => {
    it('decodes a valid unsubscribeResult', () => {
      const msg = roundTripPlugin({
        type: 'unsubscribeResult',
        sessionId: 'sess-1',
        requestId: 'req-6',
        payload: { events: ['logPush'] },
      });
      expect(msg).toEqual({
        type: 'unsubscribeResult',
        sessionId: 'sess-1',
        requestId: 'req-6',
        payload: { events: ['logPush'] },
      });
    });

    it('returns null without requestId', () => {
      expect(roundTripPlugin({
        type: 'unsubscribeResult',
        sessionId: 'sess-1',
        payload: { events: [] },
      })).toBeNull();
    });
  });

  describe('error (plugin)', () => {
    it('decodes error with requestId', () => {
      const msg = roundTripPlugin({
        type: 'error',
        sessionId: 'sess-1',
        requestId: 'req-7',
        payload: { code: 'TIMEOUT', message: 'Request timed out' },
      });
      expect(msg).toEqual({
        type: 'error',
        sessionId: 'sess-1',
        requestId: 'req-7',
        payload: { code: 'TIMEOUT', message: 'Request timed out', details: undefined },
      });
    });

    it('decodes error without requestId', () => {
      const msg = roundTripPlugin({
        type: 'error',
        sessionId: 'sess-1',
        payload: { code: 'INTERNAL_ERROR', message: 'Something failed' },
      });
      expect(msg).toEqual({
        type: 'error',
        sessionId: 'sess-1',
        payload: { code: 'INTERNAL_ERROR', message: 'Something failed', details: undefined },
      });
      expect(msg).not.toHaveProperty('requestId');
    });

    it('decodes error with details', () => {
      const msg = roundTripPlugin({
        type: 'error',
        sessionId: 'sess-1',
        requestId: 'req-8',
        payload: { code: 'INVALID_PAYLOAD', message: 'Bad data', details: { field: 'path' } },
      });
      expect(msg).not.toBeNull();
      expect((msg as any).payload.details).toEqual({ field: 'path' });
    });

    it('returns null without code', () => {
      expect(roundTripPlugin({
        type: 'error',
        sessionId: 'sess-1',
        payload: { message: 'No code' },
      })).toBeNull();
    });

    it('returns null without message', () => {
      expect(roundTripPlugin({
        type: 'error',
        sessionId: 'sess-1',
        payload: { code: 'TIMEOUT' },
      })).toBeNull();
    });
  });
});

// ---------------------------------------------------------------------------
// v2 Server → Plugin messages (encodeMessage + decodeServerMessage round-trip)
// ---------------------------------------------------------------------------

describe('encodeMessage / decodeServerMessage (v2)', () => {
  describe('v1 backward compatibility', () => {
    it('round-trips welcome', () => {
      const msg: ServerMessage = {
        type: 'welcome',
        sessionId: 'sess-1',
        payload: { sessionId: 'sess-1' },
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('round-trips execute without requestId', () => {
      const msg: ServerMessage = {
        type: 'execute',
        sessionId: 'sess-1',
        payload: { script: 'print("hi")' },
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('round-trips execute with requestId', () => {
      const msg: ServerMessage = {
        type: 'execute',
        sessionId: 'sess-1',
        requestId: 'req-99',
        payload: { script: 'print("hi")' },
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('round-trips shutdown', () => {
      const msg: ServerMessage = {
        type: 'shutdown',
        sessionId: 'sess-1',
        payload: {} as Record<string, never>,
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });
  });

  describe('queryState', () => {
    it('round-trips queryState', () => {
      const msg: ServerMessage = {
        type: 'queryState',
        sessionId: 'sess-1',
        requestId: 'req-10',
        payload: {} as Record<string, never>,
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('returns null without requestId', () => {
      expect(decodeServerMessage(JSON.stringify({
        type: 'queryState',
        sessionId: 'sess-1',
        payload: {},
      }))).toBeNull();
    });
  });

  describe('captureScreenshot', () => {
    it('round-trips captureScreenshot with format', () => {
      const msg: ServerMessage = {
        type: 'captureScreenshot',
        sessionId: 'sess-1',
        requestId: 'req-11',
        payload: { format: 'png' },
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('round-trips captureScreenshot without format', () => {
      const msg: ServerMessage = {
        type: 'captureScreenshot',
        sessionId: 'sess-1',
        requestId: 'req-11',
        payload: {},
      };
      const decoded = roundTripServer(msg);
      expect(decoded).not.toBeNull();
      expect(decoded!.type).toBe('captureScreenshot');
      expect((decoded as any).payload.format).toBeUndefined();
    });

    it('returns null without requestId', () => {
      expect(decodeServerMessage(JSON.stringify({
        type: 'captureScreenshot',
        sessionId: 'sess-1',
        payload: {},
      }))).toBeNull();
    });
  });

  describe('queryDataModel', () => {
    it('round-trips queryDataModel with all options', () => {
      const msg: ServerMessage = {
        type: 'queryDataModel',
        sessionId: 'sess-1',
        requestId: 'req-12',
        payload: {
          path: 'game.Workspace',
          depth: 2,
          properties: ['Name', 'Position'],
          includeAttributes: true,
          find: { name: 'Part', recursive: true },
          listServices: false,
        },
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('round-trips queryDataModel with minimal options', () => {
      const msg: ServerMessage = {
        type: 'queryDataModel',
        sessionId: 'sess-1',
        requestId: 'req-12',
        payload: { path: 'game.Workspace' },
      };
      const decoded = roundTripServer(msg);
      expect(decoded).not.toBeNull();
      expect((decoded as any).payload.path).toBe('game.Workspace');
    });

    it('returns null without path', () => {
      expect(decodeServerMessage(JSON.stringify({
        type: 'queryDataModel',
        sessionId: 'sess-1',
        requestId: 'req-12',
        payload: { depth: 1 },
      }))).toBeNull();
    });

    it('returns null without requestId', () => {
      expect(decodeServerMessage(JSON.stringify({
        type: 'queryDataModel',
        sessionId: 'sess-1',
        payload: { path: 'game.Workspace' },
      }))).toBeNull();
    });
  });

  describe('queryLogs', () => {
    it('round-trips queryLogs with all options', () => {
      const msg: ServerMessage = {
        type: 'queryLogs',
        sessionId: 'sess-1',
        requestId: 'req-13',
        payload: {
          count: 50,
          direction: 'tail',
          levels: ['Error', 'Warning'],
          includeInternal: true,
        },
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('round-trips queryLogs with empty payload', () => {
      const msg: ServerMessage = {
        type: 'queryLogs',
        sessionId: 'sess-1',
        requestId: 'req-13',
        payload: {},
      };
      const decoded = roundTripServer(msg);
      expect(decoded).not.toBeNull();
      expect(decoded!.type).toBe('queryLogs');
    });

    it('returns null without requestId', () => {
      expect(decodeServerMessage(JSON.stringify({
        type: 'queryLogs',
        sessionId: 'sess-1',
        payload: {},
      }))).toBeNull();
    });
  });

  describe('subscribe', () => {
    it('round-trips subscribe', () => {
      const msg: ServerMessage = {
        type: 'subscribe',
        sessionId: 'sess-1',
        requestId: 'req-14',
        payload: { events: ['stateChange', 'logPush'] },
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('returns null without requestId', () => {
      expect(decodeServerMessage(JSON.stringify({
        type: 'subscribe',
        sessionId: 'sess-1',
        payload: { events: ['stateChange'] },
      }))).toBeNull();
    });

    it('returns null without events array', () => {
      expect(decodeServerMessage(JSON.stringify({
        type: 'subscribe',
        sessionId: 'sess-1',
        requestId: 'req-14',
        payload: {},
      }))).toBeNull();
    });
  });

  describe('unsubscribe', () => {
    it('round-trips unsubscribe', () => {
      const msg: ServerMessage = {
        type: 'unsubscribe',
        sessionId: 'sess-1',
        requestId: 'req-15',
        payload: { events: ['logPush'] },
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('returns null without requestId', () => {
      expect(decodeServerMessage(JSON.stringify({
        type: 'unsubscribe',
        sessionId: 'sess-1',
        payload: { events: [] },
      }))).toBeNull();
    });

    it('returns null without events array', () => {
      expect(decodeServerMessage(JSON.stringify({
        type: 'unsubscribe',
        sessionId: 'sess-1',
        requestId: 'req-15',
        payload: {},
      }))).toBeNull();
    });
  });

  describe('error (server)', () => {
    it('round-trips error with requestId', () => {
      const msg: ServerMessage = {
        type: 'error',
        sessionId: 'sess-1',
        requestId: 'req-16',
        payload: { code: 'CAPABILITY_NOT_SUPPORTED', message: 'Not available' },
      };
      expect(roundTripServer(msg)).toEqual({
        ...msg,
        payload: { ...msg.payload, details: undefined },
      });
    });

    it('round-trips error without requestId', () => {
      const msg: ServerMessage = {
        type: 'error',
        sessionId: 'sess-1',
        payload: { code: 'BUSY', message: 'Server busy' },
      };
      const decoded = roundTripServer(msg);
      expect(decoded).not.toBeNull();
      expect(decoded!.type).toBe('error');
      expect(decoded).not.toHaveProperty('requestId');
    });

    it('round-trips error with details', () => {
      const msg: ServerMessage = {
        type: 'error',
        sessionId: 'sess-1',
        requestId: 'req-17',
        payload: { code: 'INVALID_PAYLOAD', message: 'Bad request', details: { hint: 'missing path' } },
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('returns null without code', () => {
      expect(decodeServerMessage(JSON.stringify({
        type: 'error',
        sessionId: 'sess-1',
        payload: { message: 'No code' },
      }))).toBeNull();
    });

    it('returns null without message', () => {
      expect(decodeServerMessage(JSON.stringify({
        type: 'error',
        sessionId: 'sess-1',
        payload: { code: 'TIMEOUT' },
      }))).toBeNull();
    });
  });
});

// ---------------------------------------------------------------------------
// decodeServerMessage — malformed messages
// ---------------------------------------------------------------------------

describe('decodeServerMessage (malformed)', () => {
  it('returns null for invalid JSON', () => {
    expect(decodeServerMessage('not json')).toBeNull();
  });

  it('returns null for non-object JSON', () => {
    expect(decodeServerMessage('"just a string"')).toBeNull();
  });

  it('returns null for missing type', () => {
    expect(decodeServerMessage(JSON.stringify({ sessionId: 's', payload: {} }))).toBeNull();
  });

  it('returns null for missing payload', () => {
    expect(decodeServerMessage(JSON.stringify({ type: 'welcome', sessionId: 's' }))).toBeNull();
  });

  it('returns null for missing sessionId', () => {
    expect(decodeServerMessage(JSON.stringify({ type: 'welcome', payload: { sessionId: 's' } }))).toBeNull();
  });

  it('returns null for unknown message type', () => {
    expect(decodeServerMessage(JSON.stringify({ type: 'unknown', sessionId: 's', payload: {} }))).toBeNull();
  });
});
