/**
 * WebSocket message protocol shared between the Node.js server and the Roblox
 * Studio plugin. All messages are JSON-encoded: `{ type: string, sessionId: string, payload: object }`.
 */

export type OutputLevel = 'Print' | 'Info' | 'Warning' | 'Error';

export type StudioState =
  | 'Edit'
  | 'Play'
  | 'Paused'
  | 'Run'
  | 'Server'
  | 'Client';

export type PluginContext = 'edit' | 'client' | 'server';

export type Capability =
  | 'execute'
  | 'queryState'
  | 'captureScreenshot'
  | 'queryDataModel'
  | 'queryLogs'
  | 'exportInstances'
  | 'importInstances'
  | 'findInstances'
  | 'grepScripts'
  | 'startPlaytest'
  | 'endPlaytest'
  | 'heartbeat'
  | 'registerAction'
  | 'syncActions';

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
  | 'SCRIPT_TIMEOUT'
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
  | {
      type: 'CFrame';
      value: [
        number,
        number,
        number,
        number,
        number,
        number,
        number,
        number,
        number,
        number,
        number,
        number
      ];
    }
  | { type: 'Color3'; value: [number, number, number] }
  | { type: 'UDim2'; value: [number, number, number, number] }
  | { type: 'UDim'; value: [number, number] }
  | { type: 'BrickColor'; name: string; value: number }
  | { type: 'EnumItem'; enum: string; name: string; value: number }
  | { type: 'Instance'; className: string; path: string }
  | { type: 'Unsupported'; typeName: string; toString: string };

/**
 * A value returned by an executed script, marshalled for the wire: everything
 * `SerializedValue` covers, plus tables, which the plugin walks recursively
 * (array-like tables stay arrays, anything else becomes an object with string
 * keys).
 *
 * `{ type: 'Nil' }` stands in for a `nil` return value: a JSON array cannot
 * hold a hole, and dropping the entry would silently shift every value after
 * it, misreporting which value was returned where.
 */
export type SerializedReturnValue =
  | SerializedValue
  | { type: 'Nil' }
  | SerializedReturnValue[]
  | { [key: string]: SerializedReturnValue };

export interface DataModelInstance {
  name: string;
  className: string;
  path: string;
  properties: Record<string, SerializedValue>;
  attributes: Record<string, SerializedValue>;
  childCount: number;
  children?: DataModelInstance[];
}

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

export interface ScriptCompleteMessage extends BaseMessage {
  type: 'scriptComplete';
  requestId?: string;
  payload: {
    success: boolean;
    error?: string;
    /** Where a runtime error was thrown, as `debug.traceback` prints it. */
    traceback?: string;
    output?: Array<{ level: string; body: string; timestamp: number }>;
    /**
     * Everything the script returned, in order, marshalled by the plugin.
     * Absent when the plugin never reported a return channel (a script that
     * failed before returning) — distinct from `[]`,
     * which means the script ran and returned nothing.
     */
    returnValues?: SerializedReturnValue[];
  };
}

export interface RegisterMessage extends PushMessage {
  type: 'register';
  payload: {
    pluginVersion: string;
    instanceId: string;
    placeName: string;
    placeFile?: string;
    state: StudioState;
    /** Which DataModel the plugin runs in. Older plugins leave it out. */
    context?: PluginContext;
    pid?: number;
    /** Set when `process run` launched this Studio, from the place it opened. */
    launchId?: string;
    /** The player of a multiplayer test client. */
    playerName?: string;
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
    /** The camera's viewport in pixels. Absent without a camera. */
    viewportSize?: [number, number];
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

export interface ExportInstancesResultMessage extends RequestMessage {
  type: 'exportInstancesResult';
  payload: {
    /** The binary model (.rbxm), base64-encoded. */
    data: string;
    paths: string[];
  };
}

export interface ImportInstancesResultMessage extends RequestMessage {
  type: 'importInstancesResult';
  payload: {
    paths: string[];
  };
}

export interface FoundInstance {
  path: string;
  name: string;
  className: string;
}

export interface FindInstancesResultMessage extends RequestMessage {
  type: 'findInstancesResult';
  payload: {
    instances: FoundInstance[];
    /** How many instances were looked at. */
    searched: number;
    /** True when the search stopped at the limit. */
    truncated: boolean;
  };
}

export interface GrepMatch {
  path: string;
  className: string;
  line: number;
  text: string;
}

export interface GrepScriptsResultMessage extends RequestMessage {
  type: 'grepScriptsResult';
  payload: {
    matches: GrepMatch[];
    scriptsSearched: number;
    /** True when the search stopped at the limit. */
    truncated: boolean;
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

export interface RegisterActionResultMessage extends RequestMessage {
  type: 'registerActionResult';
  payload: {
    name: string;
    success: boolean;
    skipped?: boolean;
    error?: string;
  };
}

export interface SyncActionsResultMessage extends RequestMessage {
  type: 'syncActionsResult';
  payload: {
    needed: string[];
    installed: Record<string, string>;
  };
}

export type PlaytestMode = 'play' | 'run';

export interface PlaytestEndedMessage extends RequestMessage {
  type: 'playtestEnded';
  payload: {
    playtestId: string;
    success: boolean;
    error?: string;
  };
}

export interface EndPlaytestResultMessage extends RequestMessage {
  type: 'endPlaytestResult';
  payload: {
    playtestId?: string;
    /** Absent from plugins older than this field. */
    mode?: PlaytestMode;
    /** How many players a multiplayer test started with. */
    players?: number;
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
  | ScriptCompleteMessage
  | RegisterMessage
  | StateResultMessage
  | ScreenshotResultMessage
  | DataModelResultMessage
  | ExportInstancesResultMessage
  | ImportInstancesResultMessage
  | FindInstancesResultMessage
  | GrepScriptsResultMessage
  | LogsResultMessage
  | StateChangeMessage
  | HeartbeatMessage
  | RegisterActionResultMessage
  | SyncActionsResultMessage
  | PlaytestEndedMessage
  | EndPlaytestResultMessage
  | PluginErrorMessage;

export interface ExecuteMessage extends BaseMessage {
  type: 'execute';
  requestId?: string;
  payload: {
    script: string;
    /** The plugin cancels the script once it runs this long. */
    timeoutMs?: number;
    /** Passed to the script as `...`. */
    args?: string[];
  };
}

export interface ShutdownMessage extends PushMessage {
  type: 'shutdown';
  payload: Record<string, never>;
}

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

export interface ExportInstancesMessage extends RequestMessage {
  type: 'exportInstances';
  payload: {
    paths: string[];
  };
}

export interface ImportInstancesMessage extends RequestMessage {
  type: 'importInstances';
  payload: {
    /** The binary model (.rbxm), base64-encoded. */
    data: string;
    parentPath: string;
  };
}

export interface FindInstancesMessage extends RequestMessage {
  type: 'findInstances';
  payload: {
    /** Dot-separated path to search under. Defaults to the whole DataModel. */
    root?: string;
    /** Matched case-insensitively anywhere in the name. */
    name?: string;
    /** Match the whole name instead. */
    exactName?: boolean;
    /** Matched with IsA. */
    className?: string;
    tag?: string;
    limit?: number;
  };
}

export interface GrepScriptsMessage extends RequestMessage {
  type: 'grepScripts';
  payload: {
    pattern: string;
    /** Dot-separated path to search under. Defaults to the whole DataModel. */
    root?: string;
    /** Treat `pattern` as a Lua pattern instead of plain text. */
    luaPattern?: boolean;
    caseSensitive?: boolean;
    limit?: number;
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
    /** Only entries logged at or after this time, in epoch seconds. */
    since?: number;
  };
}

export interface RegisterActionMessage extends RequestMessage {
  type: 'registerAction';
  payload: {
    name: string;
    source: string;
    hash?: string;
    responseType?: string;
  };
}

export interface SyncActionsMessage extends RequestMessage {
  type: 'syncActions';
  payload: {
    actions: Record<string, string>;
    verbose?: boolean;
  };
}

export interface StartPlaytestMessage extends RequestMessage {
  type: 'startPlaytest';
  payload: {
    mode: PlaytestMode;
    playtestId: string;
    /** Handed to the playtest's DataModels, which can't discover the bridge themselves. */
    bridgePort: number;
    /** The edit session's instance id, which the playtest's sessions register under. */
    instanceId: string;
    /** Starts a multiplayer test, a server and a client process per player. */
    players?: number;
  };
}

export interface EndPlaytestMessage extends RequestMessage {
  type: 'endPlaytest';
  payload: Record<string, never>;
}

/** Answered with `scriptComplete`, the same reply as `execute`. */
export interface RunPlaytestScriptMessage extends RequestMessage {
  type: 'runPlaytestScript';
  payload: {
    mode: PlaytestMode;
    script: string;
    /** Planted in the playtest's server to run the script and end the playtest. */
    runnerSource: string;
    timeoutSec: number;
    /** Passed to the script as `...`. */
    args?: string[];
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
  | ExecuteMessage
  | ShutdownMessage
  | QueryStateMessage
  | CaptureScreenshotMessage
  | QueryDataModelMessage
  | ExportInstancesMessage
  | ImportInstancesMessage
  | FindInstancesMessage
  | GrepScriptsMessage
  | QueryLogsMessage
  | RegisterActionMessage
  | SyncActionsMessage
  | StartPlaytestMessage
  | EndPlaytestMessage
  | RunPlaytestScriptMessage
  | ServerErrorMessage;

export function encodeMessage(msg: ServerMessage): string {
  return JSON.stringify(msg);
}

function isViewportSize(value: unknown): value is [number, number] {
  return (
    Array.isArray(value) &&
    value.length === 2 &&
    value.every((item) => typeof item === 'number')
  );
}

function isStringArray(value: unknown): value is string[] {
  return (
    Array.isArray(value) && value.every((item) => typeof item === 'string')
  );
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
  if (
    typeof obj.type !== 'string' ||
    typeof obj.payload !== 'object' ||
    obj.payload === null
  ) {
    return null;
  }

  if (typeof obj.sessionId !== 'string') {
    return null;
  }

  const { type, sessionId, payload } = obj as {
    type: string;
    sessionId: string;
    payload: Record<string, unknown>;
  };
  const requestId =
    typeof obj.requestId === 'string' ? obj.requestId : undefined;

  switch (type) {
    case 'scriptComplete':
      if (typeof payload.success === 'boolean') {
        const output = Array.isArray(payload.output)
          ? (payload.output as Array<Record<string, unknown>>)
              .filter(
                (e): e is { level: string; body: string; timestamp: number } =>
                  typeof e === 'object' &&
                  e !== null &&
                  typeof e.level === 'string' &&
                  typeof e.body === 'string'
              )
              .map((e) => ({
                level: e.level,
                body: e.body,
                timestamp: typeof e.timestamp === 'number' ? e.timestamp : 0,
              }))
          : undefined;
        // The values themselves are whatever the script returned, so they are
        // carried through as-is; only the array wrapper is checked.
        const returnValues = Array.isArray(payload.returnValues)
          ? (payload.returnValues as SerializedReturnValue[])
          : undefined;
        return {
          type: 'scriptComplete',
          sessionId,
          ...(requestId !== undefined ? { requestId } : {}),
          payload: {
            success: payload.success,
            error:
              typeof payload.error === 'string' ? payload.error : undefined,
            traceback:
              typeof payload.traceback === 'string'
                ? payload.traceback
                : undefined,
            output,
            returnValues,
          },
        };
      }
      return null;

    case 'register': {
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
        payload: {
          pluginVersion: payload.pluginVersion,
          instanceId: payload.instanceId,
          placeName: payload.placeName,
          placeFile:
            typeof payload.placeFile === 'string'
              ? payload.placeFile
              : undefined,
          state: stateVal as StudioState,
          context:
            payload.context === 'edit' ||
            payload.context === 'client' ||
            payload.context === 'server'
              ? payload.context
              : undefined,
          pid: typeof payload.pid === 'number' ? payload.pid : undefined,
          launchId:
            typeof payload.launchId === 'string' ? payload.launchId : undefined,
          playerName:
            typeof payload.playerName === 'string'
              ? payload.playerName
              : undefined,
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
          viewportSize: isViewportSize(payload.viewportSize)
            ? payload.viewportSize
            : undefined,
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
      if (typeof payload.instance !== 'object' || payload.instance === null)
        return null;
      return {
        type: 'dataModelResult',
        sessionId,
        requestId,
        payload: {
          instance: payload.instance as DataModelInstance,
        },
      };

    case 'exportInstancesResult':
      if (requestId === undefined) return null;
      if (typeof payload.data !== 'string' || !isStringArray(payload.paths))
        return null;
      return {
        type: 'exportInstancesResult',
        sessionId,
        requestId,
        payload: { data: payload.data, paths: payload.paths },
      };

    case 'importInstancesResult':
      if (requestId === undefined) return null;
      if (!isStringArray(payload.paths)) return null;
      return {
        type: 'importInstancesResult',
        sessionId,
        requestId,
        payload: { paths: payload.paths },
      };

    case 'findInstancesResult':
      if (requestId === undefined) return null;
      if (!Array.isArray(payload.instances)) return null;
      return {
        type: 'findInstancesResult',
        sessionId,
        requestId,
        payload: {
          instances: payload.instances as FoundInstance[],
          searched: typeof payload.searched === 'number' ? payload.searched : 0,
          truncated: payload.truncated === true,
        },
      };

    case 'grepScriptsResult':
      if (requestId === undefined) return null;
      if (!Array.isArray(payload.matches)) return null;
      return {
        type: 'grepScriptsResult',
        sessionId,
        requestId,
        payload: {
          matches: payload.matches as GrepMatch[],
          scriptsSearched:
            typeof payload.scriptsSearched === 'number'
              ? payload.scriptsSearched
              : 0,
          truncated: payload.truncated === true,
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
          entries: payload.entries as Array<{
            level: OutputLevel;
            body: string;
            timestamp: number;
          }>,
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
      return {
        type: 'heartbeat',
        sessionId,
        payload: {
          uptimeMs: typeof payload.uptimeMs === 'number' ? payload.uptimeMs : 0,
          state:
            typeof payload.state === 'string'
              ? (payload.state as StudioState)
              : 'Edit',
          pendingRequests:
            typeof payload.pendingRequests === 'number'
              ? payload.pendingRequests
              : 0,
        },
      };

    case 'registerActionResult':
      if (requestId === undefined) return null;
      if (
        typeof payload.name !== 'string' ||
        typeof payload.success !== 'boolean'
      )
        return null;
      return {
        type: 'registerActionResult',
        sessionId,
        requestId,
        payload: {
          name: payload.name,
          success: payload.success,
          skipped:
            typeof payload.skipped === 'boolean' ? payload.skipped : undefined,
          error: typeof payload.error === 'string' ? payload.error : undefined,
        },
      };

    case 'syncActionsResult':
      if (requestId === undefined) return null;
      if (
        !Array.isArray(payload.needed) ||
        typeof payload.installed !== 'object' ||
        payload.installed === null
      )
        return null;
      return {
        type: 'syncActionsResult',
        sessionId,
        requestId,
        payload: {
          needed: payload.needed as string[],
          installed: payload.installed as Record<string, string>,
        },
      };

    case 'playtestEnded':
      if (requestId === undefined) return null;
      if (
        typeof payload.playtestId !== 'string' ||
        typeof payload.success !== 'boolean'
      )
        return null;
      return {
        type: 'playtestEnded',
        sessionId,
        requestId,
        payload: {
          playtestId: payload.playtestId,
          success: payload.success,
          error: typeof payload.error === 'string' ? payload.error : undefined,
        },
      };

    case 'endPlaytestResult':
      if (requestId === undefined) return null;
      return {
        type: 'endPlaytestResult',
        sessionId,
        requestId,
        payload: {
          playtestId:
            typeof payload.playtestId === 'string'
              ? payload.playtestId
              : undefined,
          mode:
            payload.mode === 'play' || payload.mode === 'run'
              ? payload.mode
              : undefined,
          players:
            typeof payload.players === 'number' ? payload.players : undefined,
        },
      };

    case 'error':
      if (
        typeof payload.code !== 'string' ||
        typeof payload.message !== 'string'
      )
        return null;
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
  if (
    typeof obj.type !== 'string' ||
    typeof obj.payload !== 'object' ||
    obj.payload === null
  ) {
    return null;
  }

  if (typeof obj.sessionId !== 'string') {
    return null;
  }

  const { type, sessionId, payload } = obj as {
    type: string;
    sessionId: string;
    payload: Record<string, unknown>;
  };
  const requestId =
    typeof obj.requestId === 'string' ? obj.requestId : undefined;

  switch (type) {
    case 'execute':
      if (typeof payload.script === 'string') {
        return {
          type: 'execute',
          sessionId,
          ...(requestId !== undefined ? { requestId } : {}),
          payload: {
            script: payload.script,
            ...(typeof payload.timeoutMs === 'number'
              ? { timeoutMs: payload.timeoutMs }
              : {}),
            ...(isStringArray(payload.args) ? { args: payload.args } : {}),
          },
        };
      }
      return null;

    case 'shutdown':
      return {
        type: 'shutdown',
        sessionId,
        payload: {} as Record<string, never>,
      };

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

    case 'exportInstances':
      if (requestId === undefined) return null;
      if (!isStringArray(payload.paths)) return null;
      return {
        type: 'exportInstances',
        sessionId,
        requestId,
        payload: { paths: payload.paths },
      };

    case 'importInstances':
      if (requestId === undefined) return null;
      if (
        typeof payload.data !== 'string' ||
        typeof payload.parentPath !== 'string'
      )
        return null;
      return {
        type: 'importInstances',
        sessionId,
        requestId,
        payload: { data: payload.data, parentPath: payload.parentPath },
      };

    case 'findInstances':
      if (requestId === undefined) return null;
      return {
        type: 'findInstances',
        sessionId,
        requestId,
        payload: {
          root: typeof payload.root === 'string' ? payload.root : undefined,
          name: typeof payload.name === 'string' ? payload.name : undefined,
          exactName:
            typeof payload.exactName === 'boolean'
              ? payload.exactName
              : undefined,
          className:
            typeof payload.className === 'string'
              ? payload.className
              : undefined,
          tag: typeof payload.tag === 'string' ? payload.tag : undefined,
          limit: typeof payload.limit === 'number' ? payload.limit : undefined,
        },
      };

    case 'grepScripts':
      if (requestId === undefined) return null;
      if (typeof payload.pattern !== 'string') return null;
      return {
        type: 'grepScripts',
        sessionId,
        requestId,
        payload: {
          pattern: payload.pattern,
          root: typeof payload.root === 'string' ? payload.root : undefined,
          luaPattern:
            typeof payload.luaPattern === 'boolean'
              ? payload.luaPattern
              : undefined,
          caseSensitive:
            typeof payload.caseSensitive === 'boolean'
              ? payload.caseSensitive
              : undefined,
          limit: typeof payload.limit === 'number' ? payload.limit : undefined,
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
          properties: Array.isArray(payload.properties)
            ? (payload.properties as string[])
            : undefined,
          includeAttributes:
            typeof payload.includeAttributes === 'boolean'
              ? payload.includeAttributes
              : undefined,
          find:
            typeof payload.find === 'object' && payload.find !== null
              ? (payload.find as { name: string; recursive?: boolean })
              : undefined,
          listServices:
            typeof payload.listServices === 'boolean'
              ? payload.listServices
              : undefined,
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
          direction:
            payload.direction === 'head' || payload.direction === 'tail'
              ? payload.direction
              : undefined,
          levels: Array.isArray(payload.levels)
            ? (payload.levels as OutputLevel[])
            : undefined,
          includeInternal:
            typeof payload.includeInternal === 'boolean'
              ? payload.includeInternal
              : undefined,
          since: typeof payload.since === 'number' ? payload.since : undefined,
        },
      };

    case 'registerAction':
      if (requestId === undefined) return null;
      if (
        typeof payload.name !== 'string' ||
        typeof payload.source !== 'string'
      )
        return null;
      return {
        type: 'registerAction',
        sessionId,
        requestId,
        payload: {
          name: payload.name,
          source: payload.source,
          hash: typeof payload.hash === 'string' ? payload.hash : undefined,
          responseType:
            typeof payload.responseType === 'string'
              ? payload.responseType
              : undefined,
        },
      };

    case 'syncActions':
      if (requestId === undefined) return null;
      if (typeof payload.actions !== 'object' || payload.actions === null)
        return null;
      return {
        type: 'syncActions',
        sessionId,
        requestId,
        payload: {
          actions: payload.actions as Record<string, string>,
        },
      };

    case 'startPlaytest':
      if (requestId === undefined) return null;
      if (
        (payload.mode !== 'play' && payload.mode !== 'run') ||
        typeof payload.playtestId !== 'string' ||
        typeof payload.bridgePort !== 'number' ||
        typeof payload.instanceId !== 'string'
      )
        return null;
      return {
        type: 'startPlaytest',
        sessionId,
        requestId,
        payload: {
          mode: payload.mode,
          playtestId: payload.playtestId,
          bridgePort: payload.bridgePort,
          instanceId: payload.instanceId,
          ...(typeof payload.players === 'number'
            ? { players: payload.players }
            : {}),
        },
      };

    case 'endPlaytest':
      if (requestId === undefined) return null;
      return {
        type: 'endPlaytest',
        sessionId,
        requestId,
        payload: {} as Record<string, never>,
      };

    case 'runPlaytestScript':
      if (requestId === undefined) return null;
      if (
        (payload.mode !== 'play' && payload.mode !== 'run') ||
        typeof payload.script !== 'string' ||
        typeof payload.runnerSource !== 'string' ||
        typeof payload.timeoutSec !== 'number'
      )
        return null;
      return {
        type: 'runPlaytestScript',
        sessionId,
        requestId,
        payload: {
          mode: payload.mode,
          script: payload.script,
          runnerSource: payload.runnerSource,
          timeoutSec: payload.timeoutSec,
          ...(isStringArray(payload.args) ? { args: payload.args } : {}),
        },
      };

    case 'error':
      if (
        typeof payload.code !== 'string' ||
        typeof payload.message !== 'string'
      )
        return null;
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
