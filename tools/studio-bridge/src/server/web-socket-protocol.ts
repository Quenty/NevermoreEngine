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

/**
 * The largest message a bridge socket accepts. The plugin refuses to send a
 * reply over half this with RESULT_TOO_LARGE, so a large result fails its own
 * request instead of closing the socket under every request in flight.
 * Studio itself sends messages of at least 512 MiB.
 */
export const MAX_MESSAGE_BYTES = 512 * 1024 * 1024;

export const MAX_EXECUTE_INPUT_BYTES = 192 * 1024 * 1024;

export type Capability =
  | 'execute'
  | 'queryState'
  | 'captureScreenshot'
  | 'inspectInstance'
  | 'queryLogs'
  | 'exportInstances'
  | 'importInstances'
  | 'findInstances'
  | 'sampleInstances'
  | 'recordViewport'
  | 'grepScripts'
  | 'startPlaytest'
  | 'endPlaytest'
  | 'playtestPlayers'
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
  | 'RESULT_TOO_LARGE'
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

/** An instance `inspectInstance` serialized, down to the depth asked for. */
export interface InspectedInstance {
  name: string;
  className: string;
  path: string;
  properties: ShownValue[];
  attributes: ShownValue[];
  childCount: number;
  children?: InspectedInstance[];
}

/** A property or attribute as `inspectInstance` shows it. */
export interface ShownValue {
  name: string;
  text: string;
  value: unknown;
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
    ranAs?: RunAs;
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
    /** The playtest studio-bridge started this session's DataModel for. */
    playtestId?: string;
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
    /** Studio's version, such as `0.744.0.7440803`. Absent from older plugins. */
    studioVersion?: string;
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

/** The one instance `inspectInstance` picked out. */
export interface InspectInstanceResultMessage extends RequestMessage {
  type: 'inspectInstanceResult';
  payload: {
    instance: InspectedInstance;
  };
}

/** The `details` of the error when a query or `--root` that must pick out one instance matches several. */
export interface InstanceMatchesDetails {
  matches: InstanceRef[];
  total: number;
}

export interface ExportInstancesResultMessage extends RequestMessage {
  type: 'exportInstancesResult';
  payload: {
    /** The binary model (.rbxm), base64-encoded. */
    data: string;
    instances: InstanceRef[];
  };
}

export interface ImportInstancesResultMessage extends RequestMessage {
  type: 'importInstancesResult';
  payload: {
    instances: InstanceRef[];
  };
}

/** An instance in a list of instances an action reports (InstanceRef.lua). */
export interface InstanceRef {
  path: string;
  segments: string[];
  className: string;
}

export interface FindInstancesResultMessage extends RequestMessage {
  type: 'findInstancesResult';
  payload: {
    instances: InstanceRef[];
    /** How many instances were looked at. */
    searched: number;
    total: number;
    truncated: boolean;
  };
}

/** A value `sampleInstances` read. */
export type SampleValue = number | boolean | string;

interface SampleRowBase {
  t: number;
  frame: number;
  path: string;
}

/** A value read. */
export interface SampleValueRow extends SampleRowBase {
  kind: 'value';
  property: string;
  value: SampleValue;
}

/** An instance that entered or left what is watched. */
export interface SampleMembershipRow extends SampleRowBase {
  kind: 'added' | 'removed';
}

/** Changes counted rather than read, when too many came at once. */
export interface SampleRollupRow extends SampleRowBase {
  kind: 'rollup';
  property?: string;
  count: number;
  instances: number;
  example?: string;
  value?: string;
}

export type SampleRow = SampleValueRow | SampleMembershipRow | SampleRollupRow;

/** What `sampleInstances` watched. */
export type SampleScope = 'query' | 'selection' | 'place';

/** Which frame event a recording stepped on. */
export type RecordingClock = 'renderStep' | 'heartbeat';

/** What every recording reports about its window of frames. */
export interface RecordingStats {
  frameCount: number;
  elapsed: number;
  truncated: boolean;
  clock: RecordingClock;
}

export interface SampleInstancesResultMessage extends RequestMessage {
  type: 'sampleInstancesResult';
  payload: RecordingStats & {
    instances: InstanceRef[];
    scope: SampleScope;
    watched: number;
    rows: SampleRow[];
    refs: Record<string, InstanceRef>;
    omitted: number;
    recorded: number;
    ended?: boolean;
  };
}

export interface RecordedViewportFrame {
  t: number;
  frame: number;
  width: number;
  height: number;
  format: 'png' | 'rgba';
  data: string;
}

/** A capture `recordViewport` made but could not read. */
export interface SkippedViewportFrame {
  t: number;
  frame: number;
  reason: string;
}

export interface RecordViewportResultMessage extends RequestMessage {
  type: 'recordViewportResult';
  payload: RecordingStats & {
    frames: RecordedViewportFrame[];
    skipped: SkippedViewportFrame[];
    requested: number;
  };
}

/** A matching line, with the script it is in. */
export interface GrepMatch extends InstanceRef {
  line: number;
  text: string;
}

export interface GrepScriptsResultMessage extends RequestMessage {
  type: 'grepScriptsResult';
  payload: {
    matches: GrepMatch[];
    searched: number;
    total: number;
    scripts: number;
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
      /** With groupRepeats: how many identical entries in a row this stands for. */
      repeats?: number;
      /** With groupRepeats: when the last of the repeats was logged. */
      lastTimestamp?: number;
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
    handlers?: string[];
    outdated?: boolean;
    error?: string;
  };
}

export interface SyncActionsResultMessage extends RequestMessage {
  type: 'syncActionsResult';
  payload: {
    needed: string[];
    installed: Record<string, string>;
    failed?: Record<string, FailedActionInfo>;
  };
}

export interface FailedActionInfo {
  error: string;
  handlers?: string[];
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

export interface PlaytestPlayerPayload {
  name: string;
  userId: number;
  displayName: string;
}

export interface PlaytestPlayersResultMessage extends RequestMessage {
  type: 'playtestPlayersResult';
  payload: {
    /** The players `list` found or `add` added. */
    players?: PlaytestPlayerPayload[];
    /** The players `remove` waited for that had not left by its timeout. */
    remaining?: string[];
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
  | InspectInstanceResultMessage
  | ExportInstancesResultMessage
  | ImportInstancesResultMessage
  | FindInstancesResultMessage
  | SampleInstancesResultMessage
  | RecordViewportResultMessage
  | GrepScriptsResultMessage
  | LogsResultMessage
  | StateChangeMessage
  | HeartbeatMessage
  | RegisterActionResultMessage
  | SyncActionsResultMessage
  | PlaytestEndedMessage
  | EndPlaytestResultMessage
  | PlaytestPlayersResultMessage
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
    /** Base64 files, passed to the script as buffers in `...` before `args`. */
    inputs?: string[];
    runAs?: RunAs;
  };
}

export type RunAs = 'plugin' | 'game' | 'mcp';

export interface ShutdownMessage extends PushMessage {
  type: 'shutdown';
  payload: Record<string, never>;
}

export interface QueryStateMessage extends RequestMessage {
  type: 'queryState';
  payload: Record<string, never>;
}

/** `[x, y, width, height]` in capture pixels. */
export type ViewportRegion = [number, number, number, number];

/** How a capture is cropped and scaled before its pixels are read. */
export interface ViewportReadOptions {
  region?: ViewportRegion;
  scale?: number;
}

export interface CaptureScreenshotMessage extends RequestMessage {
  type: 'captureScreenshot';
  payload: ViewportReadOptions & {
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

/** What the plugin's `InstanceQuery` module matches on. */
export interface InstanceQuery {
  root?: string;
  query?: string;
  selector?: string;
  grep?: string;
  luaPattern?: boolean;
  caseSensitive?: boolean;
}

/** What the plugin's `FrameRecorder` module takes. */
export interface RecordingOptions {
  trigger?: string;
  duration: number;
  fps?: number;
  maxFrames?: number;
}

export interface FindInstancesMessage extends RequestMessage {
  type: 'findInstances';
  payload: InstanceQuery & {
    limit?: number;
  };
}

/** Keeps a `sampleInstances` recording running in Studio between requests. */
export interface SampleWatch {
  id: string;
  wait?: number;
  stop?: boolean;
}

export interface SampleInstancesMessage extends RequestMessage {
  type: 'sampleInstances';
  payload: InstanceQuery &
    Omit<RecordingOptions, 'duration'> & {
      duration?: number;
      selection?: boolean;
      properties?: string[];
      attributes?: string[];
      watch?: SampleWatch;
    };
}

export interface RecordViewportMessage extends RequestMessage {
  type: 'recordViewport';
  payload: RecordingOptions & ViewportReadOptions;
}

export interface GrepScriptsMessage extends RequestMessage {
  type: 'grepScripts';
  payload: Pick<InstanceQuery, 'root' | 'query' | 'selector'> & {
    pattern: string;
    /** Treat `pattern` as a Lua pattern instead of plain text. */
    luaPattern?: boolean;
    caseSensitive?: boolean;
    limit?: number;
  };
}

export interface InspectInstanceMessage extends RequestMessage {
  type: 'inspectInstance';
  payload: Omit<InstanceQuery, 'grep' | 'luaPattern' | 'caseSensitive'> & {
    selection?: boolean;
    depth?: number;
    properties?: boolean;
    attributes?: boolean;
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
    /** Collapse identical consecutive entries, before `count` applies. */
    groupRepeats?: boolean;
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
    bridge?: PlaytestBridgePayload;
  };
}

/** What a `startPlaytest` plants beside the plugin's copy. */
export interface PlaytestBridgePayload {
  precompiled: string[];
  client?: boolean;
}

export interface EndPlaytestMessage extends RequestMessage {
  type: 'endPlaytest';
  payload: Record<string, never>;
}

export type PlaytestPlayersRequest =
  | { op: 'list' }
  | { op: 'add'; count: number; timeoutSec: number }
  | { op: 'remove'; kick: string[]; names: string[]; timeoutSec: number }
  | { op: 'leave' };

export interface PlaytestPlayersMessage extends RequestMessage {
  type: 'playtestPlayers';
  payload: PlaytestPlayersRequest;
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
  | InspectInstanceMessage
  | ExportInstancesMessage
  | ImportInstancesMessage
  | FindInstancesMessage
  | SampleInstancesMessage
  | RecordViewportMessage
  | GrepScriptsMessage
  | QueryLogsMessage
  | RegisterActionMessage
  | SyncActionsMessage
  | StartPlaytestMessage
  | EndPlaytestMessage
  | PlaytestPlayersMessage
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

function pickGrepScope(query: InstanceQuery): Omit<InstanceQuery, 'grep'> {
  const { grep: _grep, ...rest } = query;
  return rest;
}

function decodeInstanceQuery(payload: Record<string, unknown>): InstanceQuery {
  return {
    root: typeof payload.root === 'string' ? payload.root : undefined,
    query: typeof payload.query === 'string' ? payload.query : undefined,
    selector:
      typeof payload.selector === 'string' ? payload.selector : undefined,
    grep: typeof payload.grep === 'string' ? payload.grep : undefined,
    luaPattern:
      typeof payload.luaPattern === 'boolean' ? payload.luaPattern : undefined,
    caseSensitive:
      typeof payload.caseSensitive === 'boolean'
        ? payload.caseSensitive
        : undefined,
  };
}

function decodeRecordingOptions(
  payload: Record<string, unknown>
): RecordingOptions | null {
  if (typeof payload.duration !== 'number') return null;
  return {
    trigger: typeof payload.trigger === 'string' ? payload.trigger : undefined,
    duration: payload.duration,
    fps: typeof payload.fps === 'number' ? payload.fps : undefined,
    maxFrames:
      typeof payload.maxFrames === 'number' ? payload.maxFrames : undefined,
  };
}

function decodeSampleWatch(value: unknown): SampleWatch | undefined {
  if (!isRecord(value) || typeof value.id !== 'string') return undefined;
  return {
    id: value.id,
    ...(typeof value.wait === 'number' ? { wait: value.wait } : {}),
    ...(value.stop === true ? { stop: true } : {}),
  };
}

function decodeRecordingStats(
  payload: Record<string, unknown>
): RecordingStats {
  return {
    frameCount: typeof payload.frameCount === 'number' ? payload.frameCount : 0,
    elapsed: typeof payload.elapsed === 'number' ? payload.elapsed : 0,
    truncated: payload.truncated === true,
    clock: payload.clock === 'heartbeat' ? 'heartbeat' : 'renderStep',
  };
}

function decodeViewportReadOptions(
  payload: Record<string, unknown>
): ViewportReadOptions {
  const region = payload.region;
  return {
    region:
      Array.isArray(region) &&
      region.length === 4 &&
      region.every((n) => typeof n === 'number')
        ? (region as ViewportRegion)
        : undefined,
    scale: typeof payload.scale === 'number' ? payload.scale : undefined,
  };
}

function isArrayOf<T>(
  value: unknown,
  isItem: (item: unknown) => item is T
): value is T[] {
  return Array.isArray(value) && value.every(isItem);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isSampleRow(value: unknown): value is SampleRow {
  if (
    !isRecord(value) ||
    typeof value.t !== 'number' ||
    typeof value.frame !== 'number' ||
    typeof value.path !== 'string'
  ) {
    return false;
  }
  switch (value.kind) {
    case 'value':
      return (
        typeof value.property === 'string' &&
        ['number', 'boolean', 'string'].includes(typeof value.value)
      );
    case 'added':
    case 'removed':
      return true;
    case 'rollup':
      return (
        typeof value.count === 'number' && typeof value.instances === 'number'
      );
    default:
      return false;
  }
}

function decodeSampleScope(value: unknown): SampleScope {
  return value === 'selection' || value === 'place' ? value : 'query';
}

function isRecordedViewportFrame(
  value: unknown
): value is RecordedViewportFrame {
  return (
    isRecord(value) &&
    typeof value.t === 'number' &&
    typeof value.frame === 'number' &&
    typeof value.width === 'number' &&
    typeof value.height === 'number' &&
    (value.format === 'png' || value.format === 'rgba') &&
    typeof value.data === 'string'
  );
}

function isSkippedViewportFrame(value: unknown): value is SkippedViewportFrame {
  return (
    isRecord(value) &&
    typeof value.t === 'number' &&
    typeof value.frame === 'number' &&
    typeof value.reason === 'string'
  );
}

function isInstanceRef(value: unknown): value is InstanceRef {
  return (
    isRecord(value) &&
    typeof value.path === 'string' &&
    isStringArray(value.segments) &&
    typeof value.className === 'string'
  );
}

function decodeInstanceRefs(value: unknown): Record<string, InstanceRef> {
  const refs: Record<string, InstanceRef> = {};
  if (isRecord(value)) {
    for (const [path, ref] of Object.entries(value)) {
      if (isInstanceRef(ref)) refs[path] = ref;
    }
  }
  return refs;
}

function isGrepMatch(value: unknown): value is GrepMatch {
  return (
    isInstanceRef(value) &&
    typeof (value as Partial<GrepMatch>).line === 'number' &&
    typeof (value as Partial<GrepMatch>).text === 'string'
  );
}

function decodeFailedActions(
  value: unknown
): Record<string, FailedActionInfo> | undefined {
  if (typeof value !== 'object' || value === null) return undefined;
  const failed: Record<string, FailedActionInfo> = {};
  for (const [name, info] of Object.entries(value)) {
    if (typeof info !== 'object' || info === null) continue;
    failed[name] = {
      error: typeof info.error === 'string' ? info.error : '',
      handlers: isStringArray(info.handlers) ? info.handlers : undefined,
    };
  }
  return failed;
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
            ...(payload.ranAs === 'plugin' ||
            payload.ranAs === 'game' ||
            payload.ranAs === 'mcp'
              ? { ranAs: payload.ranAs }
              : {}),
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
          playtestId:
            typeof payload.playtestId === 'string'
              ? payload.playtestId
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
          studioVersion:
            typeof payload.studioVersion === 'string'
              ? payload.studioVersion
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

    case 'inspectInstanceResult':
      if (requestId === undefined) return null;
      if (typeof payload.instance !== 'object' || payload.instance === null)
        return null;
      return {
        type: 'inspectInstanceResult',
        sessionId,
        requestId,
        payload: { instance: payload.instance as InspectedInstance },
      };

    case 'exportInstancesResult':
      if (requestId === undefined) return null;
      if (
        typeof payload.data !== 'string' ||
        !isArrayOf(payload.instances, isInstanceRef)
      )
        return null;
      return {
        type: 'exportInstancesResult',
        sessionId,
        requestId,
        payload: { data: payload.data, instances: payload.instances },
      };

    case 'importInstancesResult':
      if (requestId === undefined) return null;
      if (!isArrayOf(payload.instances, isInstanceRef)) return null;
      return {
        type: 'importInstancesResult',
        sessionId,
        requestId,
        payload: { instances: payload.instances },
      };

    case 'findInstancesResult':
      if (requestId === undefined) return null;
      if (!isArrayOf(payload.instances, isInstanceRef)) return null;
      return {
        type: 'findInstancesResult',
        sessionId,
        requestId,
        payload: {
          instances: payload.instances,
          searched: typeof payload.searched === 'number' ? payload.searched : 0,
          total:
            typeof payload.total === 'number'
              ? payload.total
              : payload.instances.length,
          truncated: payload.truncated === true,
        },
      };

    case 'sampleInstancesResult':
      if (requestId === undefined) return null;
      if (
        !isArrayOf(payload.rows, isSampleRow) ||
        !isArrayOf(payload.instances, isInstanceRef)
      )
        return null;
      return {
        type: 'sampleInstancesResult',
        sessionId,
        requestId,
        payload: {
          ...decodeRecordingStats(payload),
          instances: payload.instances,
          scope: decodeSampleScope(payload.scope),
          watched:
            typeof payload.watched === 'number'
              ? payload.watched
              : payload.instances.length,
          rows: payload.rows,
          refs: decodeInstanceRefs(payload.refs),
          omitted: typeof payload.omitted === 'number' ? payload.omitted : 0,
          recorded: typeof payload.recorded === 'number' ? payload.recorded : 0,
          ...(typeof payload.ended === 'boolean'
            ? { ended: payload.ended }
            : {}),
        },
      };

    case 'recordViewportResult':
      if (requestId === undefined) return null;
      if (!isArrayOf(payload.frames, isRecordedViewportFrame)) return null;
      return {
        type: 'recordViewportResult',
        sessionId,
        requestId,
        payload: {
          ...decodeRecordingStats(payload),
          frames: payload.frames,
          skipped: isArrayOf(payload.skipped, isSkippedViewportFrame)
            ? payload.skipped
            : [],
          requested:
            typeof payload.requested === 'number' ? payload.requested : 0,
        },
      };

    case 'grepScriptsResult':
      if (requestId === undefined) return null;
      if (!isArrayOf(payload.matches, isGrepMatch)) return null;
      return {
        type: 'grepScriptsResult',
        sessionId,
        requestId,
        payload: {
          matches: payload.matches,
          searched: typeof payload.searched === 'number' ? payload.searched : 0,
          total:
            typeof payload.total === 'number'
              ? payload.total
              : payload.matches.length,
          scripts: typeof payload.scripts === 'number' ? payload.scripts : 0,
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
          entries: payload.entries as LogsResultMessage['payload']['entries'],
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
          handlers: isStringArray(payload.handlers)
            ? payload.handlers
            : undefined,
          outdated: payload.outdated === true || undefined,
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
          failed: decodeFailedActions(payload.failed),
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

    case 'playtestPlayersResult':
      if (requestId === undefined) return null;
      return {
        type: 'playtestPlayersResult',
        sessionId,
        requestId,
        payload: {
          players: Array.isArray(payload.players)
            ? (payload.players as PlaytestPlayerPayload[])
            : undefined,
          remaining: isStringArray(payload.remaining)
            ? payload.remaining
            : undefined,
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
            ...(isStringArray(payload.inputs)
              ? { inputs: payload.inputs }
              : {}),
            ...(payload.runAs === 'plugin' || payload.runAs === 'game'
              ? { runAs: payload.runAs }
              : {}),
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
          ...decodeViewportReadOptions(payload),
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
          ...decodeInstanceQuery(payload),
          limit: typeof payload.limit === 'number' ? payload.limit : undefined,
        },
      };

    case 'sampleInstances': {
      if (requestId === undefined) return null;
      const watch = decodeSampleWatch(payload.watch);
      const recording = decodeRecordingOptions(
        watch ? { duration: 0, ...payload } : payload
      );
      if (!recording) return null;
      return {
        type: 'sampleInstances',
        sessionId,
        requestId,
        payload: {
          ...decodeInstanceQuery(payload),
          ...recording,
          duration:
            typeof payload.duration === 'number' ? payload.duration : undefined,
          ...(watch ? { watch } : {}),
          properties: isStringArray(payload.properties)
            ? payload.properties
            : undefined,
          attributes: isStringArray(payload.attributes)
            ? payload.attributes
            : undefined,
        },
      };
    }

    case 'recordViewport': {
      if (requestId === undefined) return null;
      const recording = decodeRecordingOptions(payload);
      if (!recording) return null;
      return {
        type: 'recordViewport',
        sessionId,
        requestId,
        payload: { ...recording, ...decodeViewportReadOptions(payload) },
      };
    }

    case 'grepScripts':
      if (requestId === undefined) return null;
      if (typeof payload.pattern !== 'string') return null;
      return {
        type: 'grepScripts',
        sessionId,
        requestId,
        payload: {
          ...pickGrepScope(decodeInstanceQuery(payload)),
          pattern: payload.pattern,
          limit: typeof payload.limit === 'number' ? payload.limit : undefined,
        },
      };

    case 'inspectInstance': {
      if (requestId === undefined) return null;
      const { root, query, selector } = decodeInstanceQuery(payload);
      return {
        type: 'inspectInstance',
        sessionId,
        requestId,
        payload: {
          root,
          query,
          selector,
          selection:
            typeof payload.selection === 'boolean'
              ? payload.selection
              : undefined,
          depth: typeof payload.depth === 'number' ? payload.depth : undefined,
          properties:
            typeof payload.properties === 'boolean'
              ? payload.properties
              : undefined,
          attributes:
            typeof payload.attributes === 'boolean'
              ? payload.attributes
              : undefined,
        },
      };
    }

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
          groupRepeats:
            typeof payload.groupRepeats === 'boolean'
              ? payload.groupRepeats
              : undefined,
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
          ...(isPlaytestBridge(payload.bridge)
            ? { bridge: payload.bridge }
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

    case 'playtestPlayers':
      if (requestId === undefined) return null;
      if (!isPlaytestPlayersRequest(payload)) return null;
      return {
        type: 'playtestPlayers',
        sessionId,
        requestId,
        payload,
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

function isPlaytestBridge(value: unknown): value is PlaytestBridgePayload {
  if (typeof value !== 'object' || value === null) return false;
  const bridge = value as Record<string, unknown>;
  return (
    isStringArray(bridge.precompiled) &&
    (bridge.client === undefined || typeof bridge.client === 'boolean')
  );
}

function isPlaytestPlayersRequest(
  value: Record<string, unknown>
): value is PlaytestPlayersRequest {
  switch (value.op) {
    case 'list':
    case 'leave':
      return true;
    case 'add':
      return (
        typeof value.count === 'number' && typeof value.timeoutSec === 'number'
      );
    case 'remove':
      return (
        isStringArray(value.kick) &&
        isStringArray(value.names) &&
        typeof value.timeoutSec === 'number'
      );
    default:
      return false;
  }
}
