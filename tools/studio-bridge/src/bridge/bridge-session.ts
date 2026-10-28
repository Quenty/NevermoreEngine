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
  ExportInstancesResult,
  ImportInstancesResult,
  LogOptions,
  QueryDataModelOptions,
  PlaytestMode,
  PlaytestEndResult,
  EndPlaytestResult,
} from './types.js';
import { SessionDisconnectedError } from './types.js';
import type {
  PluginMessage,
  OutputLevel,
  FindInstancesMessage,
  FindInstancesResultMessage,
  GrepScriptsMessage,
  GrepScriptsResultMessage,
} from '../server/web-socket-protocol.js';
import {
  loadActionSourcesAsync,
  type ActionSource,
} from '../commands/framework/action-loader.js';
import { OutputHelper } from '@quenty/cli-output-helpers';

const EXECUTE_REPLY_GRACE_MS = 5_000;

const DEFAULT_TIMEOUTS: Record<string, number> = {
  execute: 120_000,
  queryState: 5_000,
  captureScreenshot: 30_000,
  queryDataModel: 10_000,
  exportInstances: 60_000,
  importInstances: 60_000,
  findInstances: 60_000,
  grepScripts: 60_000,
  queryLogs: 10_000,
  endPlaytest: 5_000,
};

/** Time a playtest gets to start and stop on top of its script's own timeout. */
const PLAYTEST_STARTUP_ALLOWANCE_MS = 60_000;

export interface RunPlaytestScriptOptions {
  mode: PlaytestMode;
  script: string;
  runnerSource: string;
  timeoutSec: number;
  /** Passed to the script as `...`. */
  args?: string[];
}

/** Map an `execute`-style reply onto an ExecResult. */
function toExecResult(result: PluginMessage): ExecResult {
  if (result.type === 'scriptComplete') {
    const output = (result.payload.output ?? []).map((entry) => ({
      level: entry.level as OutputLevel,
      body: entry.body,
    }));
    return {
      success: result.payload.success,
      output,
      error: result.payload.error,
      traceback: result.payload.traceback,
      returnValues: result.payload.returnValues,
    };
  }

  if (result.type === 'error') {
    return {
      success: false,
      output: [],
      error: result.payload?.message ?? 'Unknown plugin error',
    };
  }

  return {
    success: false,
    output: [],
    error: pluginError('scriptComplete', result).message,
  };
}

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
    `Expected '${expectedType}' response from plugin, got '${result.type}'`
  );
}

export class BridgeSession extends EventEmitter {
  private _info: SessionInfo;
  private _handle: TransportHandle;
  private _actionsReady = false;
  private _actionSources: ActionSource[] | undefined;

  constructor(info: SessionInfo, handle: TransportHandle) {
    super();
    this._info = info;
    this._handle = handle;

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

  async execAsync(
    code: string,
    timeout?: number,
    args?: string[]
  ): Promise<ExecResult> {
    this._assertConnected();
    await this._ensureActionsAsync();

    // The plugin cancels the script at the timeout and replies, so wait a
    // little longer than that for the reply
    const timeoutMs = timeout ?? DEFAULT_TIMEOUTS.execute;
    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'execute',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: {
          script: code,
          timeoutMs,
          ...(args && args.length > 0 ? { args } : {}),
        },
      },
      timeoutMs + EXECUTE_REPLY_GRACE_MS
    );

    return toExecResult(result);
  }

  /**
   * Run a script in a fresh playtest's server, started from this edit
   * session, and resolve with its result once the playtest has ended. Works
   * without the playtest's own sessions connecting: the plugin plants
   * `runnerSource` in the playtest to run the script and end the playtest.
   */
  async runPlaytestScriptAsync(
    options: RunPlaytestScriptOptions
  ): Promise<ExecResult> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'runPlaytestScript',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: {
          mode: options.mode,
          script: options.script,
          runnerSource: options.runnerSource,
          timeoutSec: options.timeoutSec,
          ...(options.args && options.args.length > 0
            ? { args: options.args }
            : {}),
        },
      },
      options.timeoutSec * 1000 + PLAYTEST_STARTUP_ALLOWANCE_MS
    );

    return toExecResult(result);
  }

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
      timeoutMs
    );

    if (result.type === 'stateResult') {
      return {
        state: result.payload.state,
        placeId: result.payload.placeId,
        placeName: result.payload.placeName,
        gameId: result.payload.gameId,
        viewportSize: result.payload.viewportSize,
        studioVersion: result.payload.studioVersion,
      };
    }

    throw pluginError('stateResult', result);
  }

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
      timeoutMs
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
          ...(options?.since !== undefined ? { since: options.since } : {}),
          ...(options?.groupRepeats ? { groupRepeats: true } : {}),
        },
      },
      timeoutMs
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

  async queryDataModelAsync(
    options: QueryDataModelOptions
  ): Promise<DataModelResult> {
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
      timeoutMs
    );

    if (result.type === 'dataModelResult') {
      return {
        instance: result.payload.instance,
      };
    }

    throw pluginError('dataModelResult', result);
  }

  /** Search the DataModel for instances by name, class and tag. */
  async findInstancesAsync(
    options: FindInstancesMessage['payload']
  ): Promise<FindInstancesResultMessage['payload']> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'findInstances',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: options,
      },
      DEFAULT_TIMEOUTS.findInstances
    );

    if (result.type === 'findInstancesResult') {
      return result.payload;
    }

    throw pluginError('findInstancesResult', result);
  }

  /** Search the source of every script for a pattern. */
  async grepScriptsAsync(
    options: GrepScriptsMessage['payload']
  ): Promise<GrepScriptsResultMessage['payload']> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'grepScripts',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: options,
      },
      DEFAULT_TIMEOUTS.grepScripts
    );

    if (result.type === 'grepScriptsResult') {
      return result.payload;
    }

    throw pluginError('grepScriptsResult', result);
  }

  /** Serialize the instances at `paths` into one binary model (.rbxm). */
  async exportInstancesAsync(paths: string[]): Promise<ExportInstancesResult> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'exportInstances',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: { paths },
      },
      DEFAULT_TIMEOUTS.exportInstances
    );

    if (result.type === 'exportInstancesResult') {
      return { data: result.payload.data, paths: result.payload.paths };
    }

    throw pluginError('exportInstancesResult', result);
  }

  /** Insert a binary model (.rbxm), base64-encoded, under `parentPath`. */
  async importInstancesAsync(
    data: string,
    parentPath: string
  ): Promise<ImportInstancesResult> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'importInstances',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: { data, parentPath },
      },
      DEFAULT_TIMEOUTS.importInstances
    );

    if (result.type === 'importInstancesResult') {
      return { paths: result.payload.paths };
    }

    throw pluginError('importInstancesResult', result);
  }

  /**
   * Start a playtest from this edit session. Resolves when the playtest
   * ends, not when it starts: StudioTestService only reports a refusal to
   * start (a playtest already running) by failing the call that would have
   * waited for the end.
   */
  async runPlaytestAsync(
    mode: PlaytestMode,
    playtestId: string,
    bridgePort: number,
    timeoutMs: number,
    players?: number
  ): Promise<PlaytestEndResult> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'startPlaytest',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: {
          mode,
          playtestId,
          bridgePort,
          instanceId: this._info.instanceId,
          ...(players !== undefined ? { players } : {}),
        },
      },
      timeoutMs
    );

    if (result.type === 'playtestEnded') {
      return {
        playtestId: result.payload.playtestId,
        success: result.payload.success,
        error: result.payload.error,
      };
    }

    throw pluginError('playtestEnded', result);
  }

  /** End the playtest this server session belongs to. */
  async endPlaytestAsync(): Promise<EndPlaytestResult> {
    this._assertConnected();
    await this._ensureActionsAsync();

    const result = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'endPlaytest',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: {} as Record<string, never>,
      },
      DEFAULT_TIMEOUTS.endPlaytest
    );

    if (result.type === 'endPlaytestResult') {
      return {
        playtestId: result.payload.playtestId,
        mode: result.payload.mode,
        players: result.payload.players,
      };
    }

    throw pluginError('endPlaytestResult', result);
  }

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
      OutputHelper.verbose(
        `[actions] Loaded ${this._actionSources.length} action source(s): ${
          this._actionSources.map((a) => a.name).join(', ') || '(none)'
        }`
      );
    }

    if (this._actionSources.length === 0) {
      OutputHelper.verbose('[actions] No action sources found — skipping sync');
      this._actionsReady = true;
      return;
    }

    const actions: Record<string, string> = {};
    for (const action of this._actionSources) {
      actions[action.name] = action.hash;
    }

    OutputHelper.verbose(
      `[actions] Sending syncActions (${
        Object.keys(actions).length
      } hashes) to session ${this._info.sessionId}`
    );
    const syncResult = await this._handle.sendActionAsync<PluginMessage>(
      {
        type: 'syncActions',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: { actions, verbose: OutputHelper.isVerbose() },
      },
      10_000
    );

    if (syncResult.type === 'syncActionsResult') {
      const needed = syncResult.payload.needed as string[];
      OutputHelper.verbose(
        `[actions] syncActions response: ${
          needed.length
        } action(s) need updating${
          needed.length > 0 ? ': ' + needed.join(', ') : ''
        }`
      );

      for (const actionName of needed) {
        const action = this._actionSources.find((a) => a.name === actionName);
        if (!action) continue;

        OutputHelper.verbose(`[actions] Registering action: ${actionName}`);
        const regResult = await this._handle.sendActionAsync<PluginMessage>(
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
          10_000
        );
        if (regResult.type === 'registerActionResult') {
          const p = regResult.payload;
          OutputHelper.verbose(
            `[actions]   ${actionName}: ${
              p.success
                ? p.skipped
                  ? 'skipped (same hash)'
                  : 'registered'
                : `FAILED: ${p.error}`
            }`
          );
        } else if (regResult.type === 'error') {
          OutputHelper.verbose(
            `[actions]   ${actionName}: plugin error: ${
              (regResult as any).payload?.message ?? regResult.type
            }`
          );
        }
      }
    } else {
      OutputHelper.verbose(
        `[actions] syncActions returned unexpected type '${
          syncResult.type
        }': ${JSON.stringify((syncResult as any).payload ?? {}).slice(0, 200)}`
      );
    }

    this._actionsReady = true;
    OutputHelper.verbose('[actions] Action sync complete');
  }
}
