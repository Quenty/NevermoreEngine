import { describe, it, expect } from 'vitest';
import {
  encodeMessage,
  decodePluginMessage,
  decodeServerMessage,
  type PluginMessage,
  type ServerMessage,
} from './web-socket-protocol.js';

/** Encode a plugin message, decode it, and return the result. */
function roundTripPlugin(msg: Record<string, unknown>): PluginMessage | null {
  return decodePluginMessage(JSON.stringify(msg));
}

/** Encode a server message via encodeMessage, decode it, and return the result. */
function roundTripServer(msg: ServerMessage): ServerMessage | null {
  return decodeServerMessage(encodeMessage(msg));
}

describe('decodePluginMessage', () => {
  describe('scriptComplete', () => {
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

    it('carries returnValues through unchanged, nesting included', () => {
      const msg = roundTripPlugin({
        type: 'scriptComplete',
        sessionId: 'sess-1',
        payload: {
          success: true,
          returnValues: [
            { slug: 'maid', counts: { passed: 1014, failed: 0 } },
            'str',
            42,
            true,
            { type: 'Vector3', value: [1, 2, 3] },
            [1, 2],
          ],
        },
      });
      expect(msg?.type).toBe('scriptComplete');
      expect(
        (msg as { payload: { returnValues?: unknown[] } }).payload.returnValues
      ).toEqual([
        { slug: 'maid', counts: { passed: 1014, failed: 0 } },
        'str',
        42,
        true,
        { type: 'Vector3', value: [1, 2, 3] },
        [1, 2],
      ]);
    });

    it('leaves returnValues undefined when the plugin sent none', () => {
      // Distinguishable from an empty array: nothing reported a return channel,
      // so a caller can still fall back to the run's printed output.
      const msg = roundTripPlugin({
        type: 'scriptComplete',
        sessionId: 'sess-1',
        payload: { success: true },
      });
      expect(
        (msg as { payload: { returnValues?: unknown[] } }).payload.returnValues
      ).toBeUndefined();
    });

    it('preserves an empty returnValues array', () => {
      const msg = roundTripPlugin({
        type: 'scriptComplete',
        sessionId: 'sess-1',
        payload: { success: true, returnValues: [] },
      });
      expect(
        (msg as { payload: { returnValues?: unknown[] } }).payload.returnValues
      ).toEqual([]);
    });

    it('ignores a returnValues field that is not an array', () => {
      const msg = roundTripPlugin({
        type: 'scriptComplete',
        sessionId: 'sess-1',
        payload: { success: true, returnValues: 'nope' },
      });
      expect(
        (msg as { payload: { returnValues?: unknown[] } }).payload.returnValues
      ).toBeUndefined();
    });
  });

  describe('register', () => {
    const validRegister = {
      type: 'register',
      sessionId: 'sess-1',
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
        payload: {
          state: 'Play',
          placeId: 123,
          placeName: 'MyPlace',
          gameId: 456,
        },
      });
      expect(msg).toEqual({
        type: 'stateResult',
        sessionId: 'sess-1',
        requestId: 'req-1',
        payload: {
          state: 'Play',
          placeId: 123,
          placeName: 'MyPlace',
          gameId: 456,
        },
      });
    });

    it('returns null without requestId', () => {
      expect(
        roundTripPlugin({
          type: 'stateResult',
          sessionId: 'sess-1',
          payload: {
            state: 'Play',
            placeId: 123,
            placeName: 'MyPlace',
            gameId: 456,
          },
        })
      ).toBeNull();
    });

    it('returns null with missing payload fields', () => {
      expect(
        roundTripPlugin({
          type: 'stateResult',
          sessionId: 'sess-1',
          requestId: 'req-1',
          payload: { state: 'Play' },
        })
      ).toBeNull();
    });
  });

  describe('screenshotResult', () => {
    it('decodes a valid screenshotResult', () => {
      const msg = roundTripPlugin({
        type: 'screenshotResult',
        sessionId: 'sess-1',
        requestId: 'req-2',
        payload: {
          data: 'base64data',
          format: 'png',
          width: 1920,
          height: 1080,
        },
      });
      expect(msg).toEqual({
        type: 'screenshotResult',
        sessionId: 'sess-1',
        requestId: 'req-2',
        payload: {
          data: 'base64data',
          format: 'png',
          width: 1920,
          height: 1080,
        },
      });
    });

    it('returns null without requestId', () => {
      expect(
        roundTripPlugin({
          type: 'screenshotResult',
          sessionId: 'sess-1',
          payload: {
            data: 'base64data',
            format: 'png',
            width: 1920,
            height: 1080,
          },
        })
      ).toBeNull();
    });

    it('returns null with wrong format', () => {
      expect(
        roundTripPlugin({
          type: 'screenshotResult',
          sessionId: 'sess-1',
          requestId: 'req-2',
          payload: {
            data: 'base64data',
            format: 'jpeg',
            width: 1920,
            height: 1080,
          },
        })
      ).toBeNull();
    });
  });

  describe('inspectInstanceResult', () => {
    const instance = {
      name: 'Workspace',
      className: 'Workspace',
      path: 'Workspace',
      properties: [{ name: 'Gravity', text: '196.2', value: 196.2 }],
      attributes: [],
      childCount: 3,
      children: [],
    };

    it('decodes an inspected instance', () => {
      const msg = roundTripPlugin({
        type: 'inspectInstanceResult',
        sessionId: 'sess-1',
        requestId: 'req-3',
        payload: { instance },
      });
      expect(msg).toEqual({
        type: 'inspectInstanceResult',
        sessionId: 'sess-1',
        requestId: 'req-3',
        payload: { instance },
      });
    });

    it('returns null without requestId or an instance', () => {
      expect(
        roundTripPlugin({
          type: 'inspectInstanceResult',
          sessionId: 'sess-1',
          payload: { instance },
        })
      ).toBeNull();
      expect(
        roundTripPlugin({
          type: 'inspectInstanceResult',
          sessionId: 'sess-1',
          requestId: 'req-3',
          payload: { instance: 'not-an-object' },
        })
      ).toBeNull();
    });
  });

  describe('exportInstancesResult / importInstancesResult', () => {
    const MAP = {
      path: 'Workspace.Map',
      segments: ['Workspace', 'Map'],
      className: 'Model',
    };

    it('decodes an exported model', () => {
      const msg = {
        type: 'exportInstancesResult',
        sessionId: 'sess-1',
        requestId: 'req-1',
        payload: { data: 'PHJvYmxveCE=', instances: [MAP] },
      };
      expect(roundTripPlugin(msg)).toEqual(msg);
    });

    it('rejects an export without data', () => {
      expect(
        roundTripPlugin({
          type: 'exportInstancesResult',
          sessionId: 'sess-1',
          requestId: 'req-1',
          payload: { instances: [MAP] },
        })
      ).toBeNull();
    });

    it('decodes the imported instances', () => {
      const msg = {
        type: 'importInstancesResult',
        sessionId: 'sess-1',
        requestId: 'req-1',
        payload: { instances: [MAP] },
      };
      expect(roundTripPlugin(msg)).toEqual(msg);
    });

    it('rejects an instance without segments', () => {
      expect(
        roundTripPlugin({
          type: 'importInstancesResult',
          sessionId: 'sess-1',
          requestId: 'req-1',
          payload: {
            instances: [{ path: 'Workspace.Map', className: 'Model' }],
          },
        })
      ).toBeNull();
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
      expect(
        roundTripPlugin({
          type: 'logsResult',
          sessionId: 'sess-1',
          payload: { entries: [], total: 0, bufferCapacity: 1000 },
        })
      ).toBeNull();
    });

    it('returns null with missing total', () => {
      expect(
        roundTripPlugin({
          type: 'logsResult',
          sessionId: 'sess-1',
          requestId: 'req-4',
          payload: { entries: [], bufferCapacity: 1000 },
        })
      ).toBeNull();
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
      expect(
        roundTripPlugin({
          type: 'stateChange',
          sessionId: 'sess-1',
          payload: { previousState: 'Edit', newState: 'Play' },
        })
      ).toBeNull();
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

    it('accepts heartbeat with missing fields using defaults', () => {
      const msg = roundTripPlugin({
        type: 'heartbeat',
        sessionId: 'sess-1',
        payload: { uptimeMs: 60000, state: 'Edit' },
      });
      expect(msg).toEqual({
        type: 'heartbeat',
        sessionId: 'sess-1',
        payload: { uptimeMs: 60000, state: 'Edit', pendingRequests: 0 },
      });
    });

    it('accepts empty payload with all defaults', () => {
      const msg = roundTripPlugin({
        type: 'heartbeat',
        sessionId: 'sess-1',
        payload: {},
      });
      expect(msg).toEqual({
        type: 'heartbeat',
        sessionId: 'sess-1',
        payload: { uptimeMs: 0, state: 'Edit', pendingRequests: 0 },
      });
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
        payload: {
          code: 'TIMEOUT',
          message: 'Request timed out',
          details: undefined,
        },
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
        payload: {
          code: 'INTERNAL_ERROR',
          message: 'Something failed',
          details: undefined,
        },
      });
      expect(msg).not.toHaveProperty('requestId');
    });

    it('decodes error with details', () => {
      const msg = roundTripPlugin({
        type: 'error',
        sessionId: 'sess-1',
        requestId: 'req-8',
        payload: {
          code: 'INVALID_PAYLOAD',
          message: 'Bad data',
          details: { field: 'path' },
        },
      });
      expect(msg).not.toBeNull();
      expect((msg as any).payload.details).toEqual({ field: 'path' });
    });

    it('returns null without code', () => {
      expect(
        roundTripPlugin({
          type: 'error',
          sessionId: 'sess-1',
          payload: { message: 'No code' },
        })
      ).toBeNull();
    });

    it('returns null without message', () => {
      expect(
        roundTripPlugin({
          type: 'error',
          sessionId: 'sess-1',
          payload: { code: 'TIMEOUT' },
        })
      ).toBeNull();
    });
  });
});

describe('decodePluginMessage (recordings)', () => {
  const stats = {
    frameCount: 3,
    elapsed: 0.2,
    truncated: false,
    clock: 'renderStep',
  };
  const row = {
    kind: 'value',
    t: 0,
    frame: 0,
    path: 'A',
    property: 'Size.X.Scale',
    value: 1,
  };
  const frame = {
    t: 0,
    frame: 0,
    width: 2,
    height: 1,
    format: 'png',
    data: 'AAAA',
  };

  function sampleResult(payload: Record<string, unknown>) {
    return roundTripPlugin({
      type: 'sampleInstancesResult',
      sessionId: 'sess-1',
      requestId: 'req-1',
      payload: {
        ...stats,
        instances: [{ path: 'A', segments: ['A'], className: 'Part' }],
        recorded: 1,
        ...payload,
      },
    });
  }

  function recordResult(payload: Record<string, unknown>) {
    return roundTripPlugin({
      type: 'recordViewportResult',
      sessionId: 'sess-1',
      requestId: 'req-1',
      payload: { ...stats, requested: 3, ...payload },
    });
  }

  it('decodes sample rows', () => {
    const msg = sampleResult({ rows: [row] });
    expect(msg?.type).toBe('sampleInstancesResult');
    expect((msg as any).payload.rows).toEqual([row]);
  });

  it('decodes membership and rollup rows, and the scope', () => {
    const rows = [
      { kind: 'added', t: 0.1, frame: 1, path: 'A.B' },
      {
        kind: 'rollup',
        t: 0.5,
        frame: 30,
        path: 'A',
        property: 'CFrame',
        count: 1920,
        instances: 48,
      },
    ];
    const msg = sampleResult({ rows, scope: 'place', watched: 5000 });
    expect((msg as any).payload).toMatchObject({
      rows,
      scope: 'place',
      watched: 5000,
      omitted: 0,
    });
  });

  it('decodes the refs, and an empty map Studio sends as an array', () => {
    const refs = {
      'A.B': { path: 'A.B', segments: ['A', 'B'], className: 'Part' },
    };
    expect((sampleResult({ rows: [], refs }) as any).payload.refs).toEqual(
      refs
    );
    expect((sampleResult({ rows: [], refs: [] }) as any).payload.refs).toEqual(
      {}
    );
  });

  it('rejects a sample row of an unknown kind', () => {
    expect(sampleResult({ rows: [{ ...row, kind: 'other' }] })).toBeNull();
  });

  it('decodes whether a watched sample ended', () => {
    expect((sampleResult({ rows: [] }) as any).payload.ended).toBeUndefined();
    expect((sampleResult({ rows: [], ended: true }) as any).payload.ended).toBe(
      true
    );
  });

  it('decodes a watched sample request without a duration', () => {
    const watch = { id: 'w', wait: 0.5 };
    const msg = roundTripServer({
      type: 'sampleInstances',
      sessionId: 'sess-1',
      requestId: 'req-1',
      payload: { watch },
    });
    expect((msg as any).payload.watch).toEqual(watch);
    expect((msg as any).payload.duration).toBeUndefined();

    expect(
      roundTripServer({
        type: 'sampleInstances',
        sessionId: 'sess-1',
        requestId: 'req-1',
        payload: {},
      })
    ).toBeNull();
  });

  it('rejects a malformed sample row', () => {
    expect(sampleResult({ rows: [{ ...row, value: { x: 1 } }] })).toBeNull();
    expect(sampleResult({ rows: [{ ...row, path: 3 }] })).toBeNull();
  });

  it('decodes recorded frames and skipped captures', () => {
    const skipped = [{ t: 0.1, frame: 1, reason: 'could not read' }];
    const msg = recordResult({ frames: [frame], skipped });
    expect((msg as any).payload.frames).toEqual([frame]);
    expect((msg as any).payload.skipped).toEqual(skipped);
    expect((msg as any).payload.requested).toBe(3);
  });

  it('rejects a malformed recorded frame', () => {
    expect(recordResult({ frames: [{ ...frame, format: 'jpg' }] })).toBeNull();
    expect(
      recordResult({ frames: [{ ...frame, data: undefined }] })
    ).toBeNull();
  });
});

describe('encodeMessage / decodeServerMessage', () => {
  describe('basic messages', () => {
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
      expect(
        decodeServerMessage(
          JSON.stringify({
            type: 'queryState',
            sessionId: 'sess-1',
            payload: {},
          })
        )
      ).toBeNull();
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
      expect(
        decodeServerMessage(
          JSON.stringify({
            type: 'captureScreenshot',
            sessionId: 'sess-1',
            payload: {},
          })
        )
      ).toBeNull();
    });
  });

  describe('inspectInstance', () => {
    it('round-trips inspectInstance with all options', () => {
      const msg: ServerMessage = {
        type: 'inspectInstance',
        sessionId: 'sess-1',
        requestId: 'req-12',
        payload: {
          root: 'Workspace',
          query: 'Door',
          selector: 'Part',
          selection: false,
          depth: 2,
          properties: true,
          attributes: true,
        },
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('round-trips inspectInstance with no options, for the top level', () => {
      const decoded = roundTripServer({
        type: 'inspectInstance',
        sessionId: 'sess-1',
        requestId: 'req-12',
        payload: {},
      });
      expect(decoded).not.toBeNull();
      expect((decoded as any).payload.query).toBeUndefined();
    });

    it('returns null without requestId', () => {
      expect(
        decodeServerMessage(
          JSON.stringify({
            type: 'inspectInstance',
            sessionId: 'sess-1',
            payload: { query: 'Workspace' },
          })
        )
      ).toBeNull();
    });
  });

  describe('exportInstances / importInstances', () => {
    it('round-trips exportInstances', () => {
      const msg: ServerMessage = {
        type: 'exportInstances',
        sessionId: 'sess-1',
        requestId: 'req-1',
        payload: { paths: ['Workspace.Map', 'Lighting'] },
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('round-trips importInstances', () => {
      const msg: ServerMessage = {
        type: 'importInstances',
        sessionId: 'sess-1',
        requestId: 'req-1',
        payload: { data: 'PHJvYmxveCE=', parentPath: 'Workspace' },
      };
      expect(roundTripServer(msg)).toEqual(msg);
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
      expect(
        decodeServerMessage(
          JSON.stringify({
            type: 'queryLogs',
            sessionId: 'sess-1',
            payload: {},
          })
        )
      ).toBeNull();
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
        payload: {
          code: 'INVALID_PAYLOAD',
          message: 'Bad request',
          details: { hint: 'missing path' },
        },
      };
      expect(roundTripServer(msg)).toEqual(msg);
    });

    it('returns null without code', () => {
      expect(
        decodeServerMessage(
          JSON.stringify({
            type: 'error',
            sessionId: 'sess-1',
            payload: { message: 'No code' },
          })
        )
      ).toBeNull();
    });

    it('returns null without message', () => {
      expect(
        decodeServerMessage(
          JSON.stringify({
            type: 'error',
            sessionId: 'sess-1',
            payload: { code: 'TIMEOUT' },
          })
        )
      ).toBeNull();
    });
  });
});

describe('decodeServerMessage (malformed)', () => {
  it('returns null for invalid JSON', () => {
    expect(decodeServerMessage('not json')).toBeNull();
  });

  it('returns null for non-object JSON', () => {
    expect(decodeServerMessage('"just a string"')).toBeNull();
  });

  it('returns null for missing type', () => {
    expect(
      decodeServerMessage(JSON.stringify({ sessionId: 's', payload: {} }))
    ).toBeNull();
  });

  it('returns null for missing payload', () => {
    expect(
      decodeServerMessage(JSON.stringify({ type: 'shutdown', sessionId: 's' }))
    ).toBeNull();
  });

  it('returns null for missing sessionId', () => {
    expect(
      decodeServerMessage(JSON.stringify({ type: 'shutdown', payload: {} }))
    ).toBeNull();
  });

  it('returns null for unknown message type', () => {
    expect(
      decodeServerMessage(
        JSON.stringify({ type: 'unknown', sessionId: 's', payload: {} })
      )
    ).toBeNull();
  });
});
