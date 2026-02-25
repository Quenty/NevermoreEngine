/**
 * WebSocket message protocol shared between the Node.js server and the Roblox
 * Studio plugin. All messages are JSON-encoded: `{ type: string, sessionId: string, payload: object }`.
 *
 * v1 messages: hello, output, scriptComplete, welcome, execute, shutdown
 * v2 messages: register, queryState, stateResult, captureScreenshot, screenshotResult,
 *   queryDataModel, dataModelResult, queryLogs, logsResult, subscribe, subscribeResult,
 *   unsubscribe, unsubscribeResult, stateChange, heartbeat, error,
 *   registerAction, registerActionResult
 */

// ---------------------------------------------------------------------------
// Output levels (matches Roblox Enum.MessageType names)
// ---------------------------------------------------------------------------

export type OutputLevel = 'Print' | 'Info' | 'Warning' | 'Error';

// ---------------------------------------------------------------------------
// Shared v2 types
// ---------------------------------------------------------------------------

export type StudioState = 'Edit' | 'Play' | 'Paused' | 'Run' | 'Server' | 'Client';
export type SubscribableEvent = 'stateChange' | 'logPush';

export type Capability =
  | 'execute'
  | 'queryState'
  | 'captureScreenshot'
  | 'queryDataModel'
  | 'queryLogs'
  | 'subscribe'
  | 'heartbeat'
  | 'registerAction';

export type ErrorCode =
  | 'UNKNOWN_REQUEST'
  | 'INVALID_PAYLOAD'
  | 'TIMEOUT'
  | 'CAPABILITY_NOT_SUPPORTED'
  | 'INSTANCE_NOT_FOUND'
  | 'PROPERTY_NOT_FOUND'
  | 'SCREENSHOT_FAILED'
  | 'SCRIPT_LOAD_ERROR'
  | 'SCRIPT_RUNTIME_ERROR'
  | 'BUSY'
  | 'SESSION_MISMATCH'
  | 'INTERNAL_ERROR';

export type SerializedValue =
  | string
  | number
  | boolean
  | null
  | { type: 'Vector3'; value: [number, number, number] }
  | { type: 'Vector2'; value: [number, number] }
  | { type: 'CFrame'; value: [number, number, number, number, number, number, number, number, number, number, number, number] }
  | { type: 'Color3'; value: [number, number, number] }
  | { type: 'UDim2'; value: [number, number, number, number] }
  | { type: 'UDim'; value: [number, number] }
  | { type: 'BrickColor'; name: string; value: number }
  | { type: 'EnumItem'; enum: string; name: string; value: number }
  | { type: 'Instance'; className: string; path: string }
  | { type: 'Unsupported'; typeName: string; toString: string };

export interface DataModelInstance {
  name: string;
  className: string;
  path: string;
  properties: Record<string, SerializedValue>;
  attributes: Record<string, SerializedValue>;
  childCount: number;
  children?: DataModelInstance[];
}

// ---------------------------------------------------------------------------
// Internal base interfaces
// ---------------------------------------------------------------------------

interface BaseMessage {
  type: string;
  sessionId: string;
}

interface RequestMessage extends BaseMessage {
  requestId: string;
}

interface PushMessage extends BaseMessage {
  // no requestId
}

// ---------------------------------------------------------------------------
// Plugin → Server messages (v1)
// ---------------------------------------------------------------------------

export interface HelloMessage extends PushMessage {
  type: 'hello';
  payload: {
    sessionId: string;
    pluginVersion?: string;
    capabilities?: Capability[];
  };
}

export interface OutputMessage extends PushMessage {
  type: 'output';
  payload: {
    messages: Array<{
      level: OutputLevel;
      body: string;
    }>;
  };
}

export interface ScriptCompleteMessage extends BaseMessage {
  type: 'scriptComplete';
  requestId?: string;
  payload: {
    success: boolean;
    error?: string;
  };
}

// ---------------------------------------------------------------------------
// Plugin → Server messages (v2)
// ---------------------------------------------------------------------------

export interface RegisterMessage extends PushMessage {
  type: 'register';
  protocolVersion: number;
  payload: {
    pluginVersion: string;
    instanceId: string;
    placeName: string;
    placeFile?: string;
    state: StudioState;
    pid?: number;
    capabilities: Capability[];
  };
}

export interface StateResultMessage extends RequestMessage {
  type: 'stateResult';
  payload: {
    state: StudioState;
    placeId: number;
    placeName: string;
    gameId: number;
  };
}

export interface ScreenshotResultMessage extends RequestMessage {
  type: 'screenshotResult';
  payload: {
    data: string;
    format: 'png';
    width: number;
    height: number;
  };
}

export interface DataModelResultMessage extends RequestMessage {
  type: 'dataModelResult';
  payload: {
    instance: DataModelInstance;
  };
}

export interface LogsResultMessage extends RequestMessage {
  type: 'logsResult';
  payload: {
    entries: Array<{
      level: OutputLevel;
      body: string;
      timestamp: number;
    }>;
    total: number;
    bufferCapacity: number;
  };
}

export interface StateChangeMessage extends PushMessage {
  type: 'stateChange';
  payload: {
    previousState: StudioState;
    newState: StudioState;
    timestamp: number;
  };
}

export interface HeartbeatMessage extends PushMessage {
  type: 'heartbeat';
  payload: {
    uptimeMs: number;
    state: StudioState;
    pendingRequests: number;
  };
}

export interface SubscribeResultMessage extends RequestMessage {
  type: 'subscribeResult';
  payload: {
    events: SubscribableEvent[];
  };
}

export interface UnsubscribeResultMessage extends RequestMessage {
  type: 'unsubscribeResult';
  payload: {
    events: SubscribableEvent[];
  };
}

export interface RegisterActionResultMessage extends RequestMessage {
  type: 'registerActionResult';
  payload: {
    name: string;
    success: boolean;
    error?: string;
  };
}

export interface PluginErrorMessage extends BaseMessage {
  type: 'error';
  requestId?: string;
  payload: {
    code: ErrorCode;
    message: string;
    details?: unknown;
  };
}

export type PluginMessage =
  | HelloMessage
  | OutputMessage
  | ScriptCompleteMessage
  | RegisterMessage
  | StateResultMessage
  | ScreenshotResultMessage
  | DataModelResultMessage
  | LogsResultMessage
  | StateChangeMessage
  | HeartbeatMessage
  | SubscribeResultMessage
  | UnsubscribeResultMessage
  | RegisterActionResultMessage
  | PluginErrorMessage;

// ---------------------------------------------------------------------------
// Server → Plugin messages (v1)
// ---------------------------------------------------------------------------

export interface WelcomeMessage extends PushMessage {
  type: 'welcome';
  payload: {
    sessionId: string;
  };
}

export interface ExecuteMessage extends BaseMessage {
  type: 'execute';
  requestId?: string;
  payload: {
    script: string;
  };
}

export interface ShutdownMessage extends PushMessage {
  type: 'shutdown';
  payload: Record<string, never>;
}

// ---------------------------------------------------------------------------
// Server → Plugin messages (v2)
// ---------------------------------------------------------------------------

export interface QueryStateMessage extends RequestMessage {
  type: 'queryState';
  payload: Record<string, never>;
}

export interface CaptureScreenshotMessage extends RequestMessage {
  type: 'captureScreenshot';
  payload: {
    format?: 'png';
  };
}

export interface QueryDataModelMessage extends RequestMessage {
  type: 'queryDataModel';
  payload: {
    path: string;
    depth?: number;
    properties?: string[];
    includeAttributes?: boolean;
    find?: { name: string; recursive?: boolean };
    listServices?: boolean;
  };
}

export interface QueryLogsMessage extends RequestMessage {
  type: 'queryLogs';
  payload: {
    count?: number;
    direction?: 'head' | 'tail';
    levels?: OutputLevel[];
    includeInternal?: boolean;
  };
}

export interface SubscribeMessage extends RequestMessage {
  type: 'subscribe';
  payload: {
    events: SubscribableEvent[];
  };
}

export interface UnsubscribeMessage extends RequestMessage {
  type: 'unsubscribe';
  payload: {
    events: SubscribableEvent[];
  };
}

export interface RegisterActionMessage extends RequestMessage {
  type: 'registerAction';
  payload: {
    name: string;
    source: string;
    responseType?: string;
  };
}

export interface ServerErrorMessage extends BaseMessage {
  type: 'error';
  requestId?: string;
  payload: {
    code: ErrorCode;
    message: string;
    details?: unknown;
  };
}

export type ServerMessage =
  | WelcomeMessage
  | ExecuteMessage
  | ShutdownMessage
  | QueryStateMessage
  | CaptureScreenshotMessage
  | QueryDataModelMessage
  | QueryLogsMessage
  | SubscribeMessage
  | UnsubscribeMessage
  | RegisterActionMessage
  | ServerErrorMessage;

// ---------------------------------------------------------------------------
// Encoding / decoding helpers
// ---------------------------------------------------------------------------

export function encodeMessage(msg: ServerMessage): string {
  return JSON.stringify(msg);
}

export function decodePluginMessage(raw: string): PluginMessage | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }

  if (typeof parsed !== 'object' || parsed === null) {
    return null;
  }

  const obj = parsed as Record<string, unknown>;
  if (typeof obj.type !== 'string' || typeof obj.payload !== 'object' || obj.payload === null) {
    return null;
  }

  if (typeof obj.sessionId !== 'string') {
    return null;
  }

  const { type, sessionId, payload } = obj as { type: string; sessionId: string; payload: Record<string, unknown> };
  const requestId = typeof obj.requestId === 'string' ? obj.requestId : undefined;

  switch (type) {
    case 'hello':
      if (typeof payload.sessionId === 'string') {
        return {
          type: 'hello',
          sessionId,
          payload: {
            sessionId: payload.sessionId,
            pluginVersion: typeof payload.pluginVersion === 'string' ? payload.pluginVersion : undefined,
            capabilities: Array.isArray(payload.capabilities) ? payload.capabilities as Capability[] : undefined,
          },
        };
      }
      return null;

    case 'output':
      if (Array.isArray(payload.messages)) {
        const messages = payload.messages
          .filter(
            (m: unknown): m is { level: OutputLevel; body: string } =>
              typeof m === 'object' &&
              m !== null &&
              typeof (m as Record<string, unknown>).level === 'string' &&
              typeof (m as Record<string, unknown>).body === 'string'
          )
          .map((m) => ({ level: m.level, body: m.body }));
        return { type: 'output', sessionId, payload: { messages } };
      }
      return null;

    case 'scriptComplete':
      if (typeof payload.success === 'boolean') {
        return {
          type: 'scriptComplete',
          sessionId,
          ...(requestId !== undefined ? { requestId } : {}),
          payload: {
            success: payload.success,
            error: typeof payload.error === 'string' ? payload.error : undefined,
          },
        };
      }
      return null;

    case 'register': {
      const protocolVersion = (obj as Record<string, unknown>).protocolVersion;
      if (typeof protocolVersion !== 'number') return null;
      if (
        typeof payload.pluginVersion !== 'string' ||
        typeof payload.instanceId !== 'string' ||
        typeof payload.placeName !== 'string' ||
        !Array.isArray(payload.capabilities)
      ) {
        return null;
      }
      const stateVal = payload.state;
      if (typeof stateVal !== 'string') return null;
      return {
        type: 'register',
        sessionId,
        protocolVersion,
        payload: {
          pluginVersion: payload.pluginVersion,
          instanceId: payload.instanceId,
          placeName: payload.placeName,
          placeFile: typeof payload.placeFile === 'string' ? payload.placeFile : undefined,
          state: stateVal as StudioState,
          pid: typeof payload.pid === 'number' ? payload.pid : undefined,
          capabilities: payload.capabilities as Capability[],
        },
      };
    }

    case 'stateResult':
      if (requestId === undefined) return null;
      if (
        typeof payload.state !== 'string' ||
        typeof payload.placeId !== 'number' ||
        typeof payload.placeName !== 'string' ||
        typeof payload.gameId !== 'number'
      ) {
        return null;
      }
      return {
        type: 'stateResult',
        sessionId,
        requestId,
        payload: {
          state: payload.state as StudioState,
          placeId: payload.placeId,
          placeName: payload.placeName,
          gameId: payload.gameId,
        },
      };

    case 'screenshotResult':
      if (requestId === undefined) return null;
      if (
        typeof payload.data !== 'string' ||
        payload.format !== 'png' ||
        typeof payload.width !== 'number' ||
        typeof payload.height !== 'number'
      ) {
        return null;
      }
      return {
        type: 'screenshotResult',
        sessionId,
        requestId,
        payload: {
          data: payload.data,
          format: 'png',
          width: payload.width,
          height: payload.height,
        },
      };

    case 'dataModelResult':
      if (requestId === undefined) return null;
      if (typeof payload.instance !== 'object' || payload.instance === null) return null;
      return {
        type: 'dataModelResult',
        sessionId,
        requestId,
        payload: {
          instance: payload.instance as DataModelInstance,
        },
      };

    case 'logsResult':
      if (requestId === undefined) return null;
      if (
        !Array.isArray(payload.entries) ||
        typeof payload.total !== 'number' ||
        typeof payload.bufferCapacity !== 'number'
      ) {
        return null;
      }
      return {
        type: 'logsResult',
        sessionId,
        requestId,
        payload: {
          entries: payload.entries as Array<{ level: OutputLevel; body: string; timestamp: number }>,
          total: payload.total,
          bufferCapacity: payload.bufferCapacity,
        },
      };

    case 'stateChange':
      if (
        typeof payload.previousState !== 'string' ||
        typeof payload.newState !== 'string' ||
        typeof payload.timestamp !== 'number'
      ) {
        return null;
      }
      return {
        type: 'stateChange',
        sessionId,
        payload: {
          previousState: payload.previousState as StudioState,
          newState: payload.newState as StudioState,
          timestamp: payload.timestamp,
        },
      };

    case 'heartbeat':
      if (
        typeof payload.uptimeMs !== 'number' ||
        typeof payload.state !== 'string' ||
        typeof payload.pendingRequests !== 'number'
      ) {
        return null;
      }
      return {
        type: 'heartbeat',
        sessionId,
        payload: {
          uptimeMs: payload.uptimeMs,
          state: payload.state as StudioState,
          pendingRequests: payload.pendingRequests,
        },
      };

    case 'subscribeResult':
      if (requestId === undefined) return null;
      if (!Array.isArray(payload.events)) return null;
      return {
        type: 'subscribeResult',
        sessionId,
        requestId,
        payload: {
          events: payload.events as SubscribableEvent[],
        },
      };

    case 'unsubscribeResult':
      if (requestId === undefined) return null;
      if (!Array.isArray(payload.events)) return null;
      return {
        type: 'unsubscribeResult',
        sessionId,
        requestId,
        payload: {
          events: payload.events as SubscribableEvent[],
        },
      };

    case 'registerActionResult':
      if (requestId === undefined) return null;
      if (typeof payload.name !== 'string' || typeof payload.success !== 'boolean') return null;
      return {
        type: 'registerActionResult',
        sessionId,
        requestId,
        payload: {
          name: payload.name,
          success: payload.success,
          error: typeof payload.error === 'string' ? payload.error : undefined,
        },
      };

    case 'error':
      if (typeof payload.code !== 'string' || typeof payload.message !== 'string') return null;
      return {
        type: 'error',
        sessionId,
        ...(requestId !== undefined ? { requestId } : {}),
        payload: {
          code: payload.code as ErrorCode,
          message: payload.message,
          details: payload.details,
        },
      };

    default:
      return null;
  }
}

export function decodeServerMessage(raw: string): ServerMessage | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }

  if (typeof parsed !== 'object' || parsed === null) {
    return null;
  }

  const obj = parsed as Record<string, unknown>;
  if (typeof obj.type !== 'string' || typeof obj.payload !== 'object' || obj.payload === null) {
    return null;
  }

  if (typeof obj.sessionId !== 'string') {
    return null;
  }

  const { type, sessionId, payload } = obj as { type: string; sessionId: string; payload: Record<string, unknown> };
  const requestId = typeof obj.requestId === 'string' ? obj.requestId : undefined;

  switch (type) {
    case 'welcome':
      if (typeof payload.sessionId === 'string') {
        return { type: 'welcome', sessionId, payload: { sessionId: payload.sessionId } };
      }
      return null;

    case 'execute':
      if (typeof payload.script === 'string') {
        return {
          type: 'execute',
          sessionId,
          ...(requestId !== undefined ? { requestId } : {}),
          payload: { script: payload.script },
        };
      }
      return null;

    case 'shutdown':
      return { type: 'shutdown', sessionId, payload: {} as Record<string, never> };

    case 'queryState':
      if (requestId === undefined) return null;
      return {
        type: 'queryState',
        sessionId,
        requestId,
        payload: {} as Record<string, never>,
      };

    case 'captureScreenshot':
      if (requestId === undefined) return null;
      return {
        type: 'captureScreenshot',
        sessionId,
        requestId,
        payload: {
          format: payload.format === 'png' ? 'png' : undefined,
        },
      };

    case 'queryDataModel':
      if (requestId === undefined) return null;
      if (typeof payload.path !== 'string') return null;
      return {
        type: 'queryDataModel',
        sessionId,
        requestId,
        payload: {
          path: payload.path,
          depth: typeof payload.depth === 'number' ? payload.depth : undefined,
          properties: Array.isArray(payload.properties) ? payload.properties as string[] : undefined,
          includeAttributes: typeof payload.includeAttributes === 'boolean' ? payload.includeAttributes : undefined,
          find: typeof payload.find === 'object' && payload.find !== null ? payload.find as { name: string; recursive?: boolean } : undefined,
          listServices: typeof payload.listServices === 'boolean' ? payload.listServices : undefined,
        },
      };

    case 'queryLogs':
      if (requestId === undefined) return null;
      return {
        type: 'queryLogs',
        sessionId,
        requestId,
        payload: {
          count: typeof payload.count === 'number' ? payload.count : undefined,
          direction: payload.direction === 'head' || payload.direction === 'tail' ? payload.direction : undefined,
          levels: Array.isArray(payload.levels) ? payload.levels as OutputLevel[] : undefined,
          includeInternal: typeof payload.includeInternal === 'boolean' ? payload.includeInternal : undefined,
        },
      };

    case 'subscribe':
      if (requestId === undefined) return null;
      if (!Array.isArray(payload.events)) return null;
      return {
        type: 'subscribe',
        sessionId,
        requestId,
        payload: {
          events: payload.events as SubscribableEvent[],
        },
      };

    case 'unsubscribe':
      if (requestId === undefined) return null;
      if (!Array.isArray(payload.events)) return null;
      return {
        type: 'unsubscribe',
        sessionId,
        requestId,
        payload: {
          events: payload.events as SubscribableEvent[],
        },
      };

    case 'registerAction':
      if (requestId === undefined) return null;
      if (typeof payload.name !== 'string' || typeof payload.source !== 'string') return null;
      return {
        type: 'registerAction',
        sessionId,
        requestId,
        payload: {
          name: payload.name,
          source: payload.source,
          responseType: typeof payload.responseType === 'string' ? payload.responseType : undefined,
        },
      };

    case 'error':
      if (typeof payload.code !== 'string' || typeof payload.message !== 'string') return null;
      return {
        type: 'error',
        sessionId,
        ...(requestId !== undefined ? { requestId } : {}),
        payload: {
          code: payload.code as ErrorCode,
          message: payload.message,
          details: payload.details,
        },
      };

    default:
      return null;
  }
}
