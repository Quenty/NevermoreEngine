/**
 * Public session handle that delegates to a TransportHandle. Provides
 * typed action methods for interacting with a connected Studio plugin.
 * Works identically whether backed by a direct WebSocket connection
 * (host) or a relayed connection through the host (client).
 *
 * Consumers get BridgeSession instances from BridgeConnection -- they
 * never construct them directly.
 */

import { randomUUID } from 'crypto';
import { EventEmitter } from 'events';
import type { TransportHandle } from './internal/session-tracker.js';
import type {
  SessionInfo,
  SessionContext,
  ExecResult,
  StateResult,
  ScreenshotResult,
  LogsResult,
  DataModelResult,
  LogOptions,
  QueryDataModelOptions,
} from './types.js';
import { SessionDisconnectedError } from './types.js';
import type { SubscribableEvent, PluginMessage, OutputLevel } from '../server/web-socket-protocol.js';
import { loadActionSourcesAsync, type ActionSource } from '../commands/framework/action-loader.js';

// ---------------------------------------------------------------------------
// Default action timeouts (ms)
// ---------------------------------------------------------------------------

const DEFAULT_TIMEOUTS: Record<string, number> = {
  execute: 120_000,
  queryState: 5_000,
  captureScreenshot: 30_000,
  queryDataModel: 10_000,
  queryLogs: 10_000,
  subscribe: 5_000,
  unsubscribe: 5_000,
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Build a descriptive error from a plugin response that didn't match the
 * expected type. Extracts error details from error-typed responses.
 */
function pluginError(expectedType: string, result: PluginMessage): Error {
  if (result.type === 'error') {
    const code = result.payload?.code ?? 'UNKNOWN';
    const message = result.payload?.message ?? 'Unknown plugin error';
    return new Error(`Plugin error (${code}): ${message}`);
  }
  return new Error(
    `Expected '${expectedType}' response from plugin, got '${result.type}'`,
  );
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

export class BridgeSession extends EventEmitter {
  private _info: SessionInfo;
  private _handle: TransportHandle;
  private _actionsReady = false;
  private _actionSources: ActionSource[] | undefined;

  constructor(info: SessionInfo, handle: TransportHandle) {
    super();
    this._info = info;
    this._handle = handle;

    // Forward handle events
    this._handle.on('disconnected', () => {
      this.emit('disconnected');
    });

    this._handle.on('message', (msg: PluginMessage) => {
      if (msg.type === 'stateChange') {
        this._info = { ...this._info, state: msg.payload.newState };
        this.emit('state-changed', msg.payload.newState);
      }
    });
  }

  /** Read-only metadata about this session. */
  get info(): SessionInfo {
    return this._info;
  }

  /** Which Studio VM this session represents (edit, client, or server). */
  get context(): SessionContext {
    return this._info.context;
  }

  /** Whether the session's plugin is still connected. */
  get isConnected(): boolean {
    return this._handle.isConnected;
  }

  // -----------------------------------------------------------------------
  // Actions
  // -----------------------------------------------------------------------

  /**
   * Execute a Luau script in this Studio instance.
   */
  async execAsync(code: string, timeout?: number): Promise<ExecResult> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const timeoutMs = timeout ?? DEFAULT_TIMEOUTS.execute;
    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'execute',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: { script: code },
      },
      timeoutMs,
    );

    if (result.type === 'scriptComplete') {
      const output = (result.payload.output ?? []).map((entry) => ({
        level: entry.level as OutputLevel,
        body: entry.body,
      }));
      return {
        success: result.payload.success,
        output,
        error: result.payload.error,
      };
    }

    if (result.type === 'error') {
      return {
        success: false,
        output: [],
        error: result.payload?.message ?? 'Unknown plugin error',
      };
    }

    return { success: false, output: [], error: pluginError('scriptComplete', result).message };
  }

  /**
   * Query Studio's current run mode and place info.
   */
  async queryStateAsync(): Promise<StateResult> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const timeoutMs = DEFAULT_TIMEOUTS.queryState;
    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'queryState',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: {} as Record<string, never>,
      },
      timeoutMs,
    );

    if (result.type === 'stateResult') {
      return {
        state: result.payload.state,
        placeId: result.payload.placeId,
        placeName: result.payload.placeName,
        gameId: result.payload.gameId,
      };
    }

    throw pluginError('stateResult', result);
  }

  /**
   * Capture a viewport screenshot.
   */
  async captureScreenshotAsync(): Promise<ScreenshotResult> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const timeoutMs = DEFAULT_TIMEOUTS.captureScreenshot;
    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'captureScreenshot',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: { format: 'png' },
      },
      timeoutMs,
    );

    if (result.type === 'screenshotResult') {
      return {
        data: result.payload.data,
        format: result.payload.format,
        width: result.payload.width,
        height: result.payload.height,
      };
    }

    throw pluginError('screenshotResult', result);
  }

  /**
   * Retrieve buffered log history.
   */
  async queryLogsAsync(options?: LogOptions): Promise<LogsResult> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const timeoutMs = DEFAULT_TIMEOUTS.queryLogs;
    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'queryLogs',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: {
          count: options?.count,
          direction: options?.direction,
          levels: options?.levels,
          includeInternal: options?.includeInternal,
        },
      },
      timeoutMs,
    );

    if (result.type === 'logsResult') {
      return {
        entries: result.payload.entries,
        total: result.payload.total,
        bufferCapacity: result.payload.bufferCapacity,
      };
    }

    throw pluginError('logsResult', result);
  }

  /**
   * Query the DataModel instance tree.
   */
  async queryDataModelAsync(options: QueryDataModelOptions): Promise<DataModelResult> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const timeoutMs = DEFAULT_TIMEOUTS.queryDataModel;
    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'queryDataModel',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: {
          path: options.path,
          depth: options.depth,
          properties: options.properties,
          includeAttributes: options.includeAttributes,
          find: options.find,
          listServices: options.listServices,
        },
      },
      timeoutMs,
    );

    if (result.type === 'dataModelResult') {
      return {
        instance: result.payload.instance,
      };
    }

    throw pluginError('dataModelResult', result);
  }

  /**
   * Subscribe to push events from the plugin.
   */
  async subscribeAsync(events: SubscribableEvent[]): Promise<void> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const timeoutMs = DEFAULT_TIMEOUTS.subscribe;
    await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'subscribe',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: { events },
      },
      timeoutMs,
    );
  }

  /**
   * Unsubscribe from push events.
   */
  async unsubscribeAsync(events: SubscribableEvent[]): Promise<void> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const timeoutMs = DEFAULT_TIMEOUTS.unsubscribe;
    await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'unsubscribe',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: { events },
      },
      timeoutMs,
    );
  }

  // -----------------------------------------------------------------------
  // Private
  // -----------------------------------------------------------------------

  private _assertConnected(): void {
    if (!this._handle.isConnected) {
      throw new SessionDisconnectedError(this._info.sessionId);
    }
  }

  /**
   * Ensure action modules are synced to the plugin before first use.
   * Uses syncActions to determine which actions need updating, then
   * registers only those that are missing or have changed hashes.
   */
  private async _ensureActionsAsync(): Promise<void> {
    if (this._actionsReady) return;

    // Lazy-load action sources from this process's disk
    if (!this._actionSources) {
      this._actionSources = await loadActionSourcesAsync();
    }

    if (this._actionSources.length === 0) {
      this._actionsReady = true;
      return;
    }

    // Build hash map for syncActions
    const actions: Record<string, string> = {};
    for (const action of this._actionSources) {
      actions[action.name] = action.hash;
    }

    // Ask plugin which actions need updating
    const syncResult = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'syncActions',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: { actions },
      },
      10_000,
    );

    if (syncResult.type === 'syncActionsResult') {
      const needed = syncResult.payload.needed as string[];

      // Push only the actions that need updating
      for (const actionName of needed) {
        const action = this._actionSources.find((a) => a.name === actionName);
        if (!action) continue;

        await this._handle.sendActionAsync<PluginMessage>(
          {
            type: 'registerAction',
            sessionId: this._info.sessionId,
            requestId: randomUUID(),
            payload: {
              name: action.name,
              source: action.source,
              hash: action.hash,
            },
          },
          10_000,
        );
      }
    }

    this._actionsReady = true;
  }
}
