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
  ExportInstancesResult,
  ImportInstancesResult,
  LogOptions,
  PlaytestMode,
  PlaytestEndResult,
  EndPlaytestResult,
} from './types.js';
import { ActionTimeoutError, SessionDisconnectedError } from './types.js';
import { StudioBridgeError } from '../messages/studio-bridge-error.js';
import { warnUser } from '../messages/warn-user.js';
import { RequestTimeoutError } from '../server/pending-request-map.js';
import type {
  FailedActionInfo,
  PluginMessage,
  ServerMessage,
  OutputLevel,
  FindInstancesMessage,
  InspectInstanceMessage,
  InspectInstanceResultMessage,
  FindInstancesResultMessage,
  SampleInstancesMessage,
  SampleInstancesResultMessage,
  RecordViewportMessage,
  RecordViewportResultMessage,
  ViewportReadOptions,
  GrepScriptsMessage,
  GrepScriptsResultMessage,
} from '../server/web-socket-protocol.js';
import {
  loadActionSourcesAsync,
  type ActionSource,
} from '../commands/framework/action-loader.js';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  formatInstanceMatches,
  isInstanceMatchesDetails,
} from '../commands/shared/instance-tree.js';
import {
  MAX_EXECUTE_INPUT_BYTES,
  type PlaytestBridgePayload,
  type PlaytestPlayerPayload,
  type PlaytestPlayersRequest,
} from '../server/web-socket-protocol.js';

export interface PlaytestPlayersResult {
  players: PlaytestPlayerPayload[];
  remaining: string[];
}

const EXECUTE_REPLY_GRACE_MS = 5_000;

const DEFAULT_TIMEOUTS: Record<string, number> = {
  execute: 120_000,
  queryState: 5_000,
  captureScreenshot: 30_000,
  inspectInstance: 60_000,
  exportInstances: 60_000,
  importInstances: 60_000,
  findInstances: 60_000,
  sampleInstances: 30_000,
  recordViewport: 120_000,
  grepScripts: 60_000,
  queryLogs: 10_000,
  endPlaytest: 5_000,
};

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
      ...(result.payload.ranAs ? { ranAs: result.payload.ranAs } : {}),
    };
  }

  if (result.type === 'error') {
    return {
      success: false,
      output: [],
      error: result.payload?.message ?? 'Unknown plugin error',
    };
  }

  throw pluginError('scriptComplete', result);
}

const PLUGIN_INSTALL_FIX = "Run 'studio-bridge plugin install'.";

const BUG_ERROR_CODES = new Set(['INTERNAL_ERROR', 'UNKNOWN']);

export function pluginError(
  expectedType: string,
  result: PluginMessage,
  sessionId = result.sessionId
): Error {
  if (result.type !== 'error') {
    return new Error(
      `Expected '${expectedType}' response from plugin, got '${result.type}'`
    );
  }

  const code: string = result.payload?.code ?? 'UNKNOWN';
  const details = result.payload?.details;
  const message = isInstanceMatchesDetails(details)
    ? formatInstanceMatches(
        result.payload?.message ?? 'Several instances match',
        details
      )
    : result.payload?.message ?? 'Unknown plugin error';

  if (BUG_ERROR_CODES.has(code)) {
    return new Error(`Studio failed running '${expectedType}': ${message}`);
  }
  if (code === 'SESSION_MISMATCH') {
    return new SessionDisconnectedError(sessionId);
  }
  if (code === 'UNKNOWN_REQUEST') {
    return new StudioBridgeError({
      code: 'PLUGIN_OUTDATED',
      message:
        'The studio-bridge plugin in Studio is too old for this command.',
      fix: PLUGIN_INSTALL_FIX,
      cause: message,
    });
  }
  return new StudioBridgeError({ code, message: asSentence(message) });
}

function asSentence(message: string): string {
  const trimmed = message.trim();
  const [first, ...rest] = trimmed.split('\n');
  const sentence = /[.!?:]$/.test(first) ? first : `${first}.`;
  return [sentence, ...rest].join('\n');
}

export class BridgeSession extends EventEmitter {
  private _info: SessionInfo;
  private _handle: TransportHandle;
  private _actionsReady = false;
  private _actionSources: ActionSource[] | undefined;
  private _outdated = new Map<string, string>();
  private _warnedOutdated = new Set<string>();

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
    args?: string[],
    inputs?: Buffer[],
    runAs?: 'plugin' | 'game'
  ): Promise<ExecResult> {
    const inputBytes = (inputs ?? []).reduce((sum, b) => sum + b.length, 0);
    if (inputBytes > MAX_EXECUTE_INPUT_BYTES) {
      throw new StudioBridgeError({
        code: 'INVALID_INPUT',
        message: `The --input files add up to ${_formatMiB(
          inputBytes
        )}, over the ${_formatMiB(
          MAX_EXECUTE_INPUT_BYTES
        )} a script can be sent with.`,
        fix: 'Split the input across several runs.',
      });
    }

    this._assertConnected();
    await this._ensureActionsAsync('execute');

    // The plugin cancels the script at the timeout and replies, so wait a
    // little longer than that for the reply
    const timeoutMs = timeout ?? DEFAULT_TIMEOUTS.execute;
    const result = await this._sendAsync(
      {
        type: 'execute',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: {
          script: code,
          timeoutMs,
          ...(args && args.length > 0 ? { args } : {}),
          ...(inputs && inputs.length > 0
            ? { inputs: inputs.map((input) => input.toString('base64')) }
            : {}),
          ...(runAs ? { runAs } : {}),
        },
      },
      timeoutMs + EXECUTE_REPLY_GRACE_MS
    );

    return toExecResult(result);
  }

  async queryStateAsync(): Promise<StateResult> {
    this._assertConnected();
    await this._ensureActionsAsync('queryState');

    const timeoutMs = DEFAULT_TIMEOUTS.queryState;
    const result = await this._sendAsync(
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

  async captureScreenshotAsync(
    options: ViewportReadOptions = {}
  ): Promise<ScreenshotResult> {
    this._assertConnected();
    await this._ensureActionsAsync('captureScreenshot');

    const timeoutMs = DEFAULT_TIMEOUTS.captureScreenshot;
    const result = await this._sendAsync(
      {
        type: 'captureScreenshot',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: { format: 'png', ...options },
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
    await this._ensureActionsAsync('queryLogs');

    const timeoutMs = DEFAULT_TIMEOUTS.queryLogs;
    const result = await this._sendAsync(
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

  async inspectInstanceAsync(
    options: InspectInstanceMessage['payload']
  ): Promise<InspectInstanceResultMessage['payload']> {
    this._assertConnected();
    await this._ensureActionsAsync('inspectInstance');

    const result = await this._sendAsync(
      {
        type: 'inspectInstance',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: options,
      },
      DEFAULT_TIMEOUTS.inspectInstance
    );

    if (result.type === 'inspectInstanceResult') {
      return result.payload;
    }

    throw pluginError('inspectInstanceResult', result);
  }

  /** Search the DataModel for instances by name, class and tag. */
  async findInstancesAsync(
    options: FindInstancesMessage['payload']
  ): Promise<FindInstancesResultMessage['payload']> {
    this._assertConnected();
    await this._ensureActionsAsync('findInstances');

    const result = await this._sendAsync(
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

  async sampleInstancesAsync(
    options: SampleInstancesMessage['payload']
  ): Promise<SampleInstancesResultMessage['payload']> {
    this._assertConnected();
    await this._ensureActionsAsync('sampleInstances');

    const result = await this._sendAsync(
      {
        type: 'sampleInstances',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: options,
      },
      Math.ceil(
        (options.watch ? options.watch.wait ?? 0 : options.duration ?? 0) * 1000
      ) + DEFAULT_TIMEOUTS.sampleInstances
    );

    if (result.type === 'sampleInstancesResult') {
      return result.payload;
    }

    throw pluginError('sampleInstancesResult', result);
  }

  async recordViewportAsync(
    options: RecordViewportMessage['payload']
  ): Promise<RecordViewportResultMessage['payload']> {
    this._assertConnected();
    await this._ensureActionsAsync('recordViewport');

    const result = await this._sendAsync(
      {
        type: 'recordViewport',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: options,
      },
      Math.ceil(options.duration * 1000) + DEFAULT_TIMEOUTS.recordViewport
    );

    if (result.type === 'recordViewportResult') {
      return result.payload;
    }

    throw pluginError('recordViewportResult', result);
  }

  /** Search the source of every script for a pattern. */
  async grepScriptsAsync(
    options: GrepScriptsMessage['payload']
  ): Promise<GrepScriptsResultMessage['payload']> {
    this._assertConnected();
    await this._ensureActionsAsync('grepScripts');

    const result = await this._sendAsync(
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
    await this._ensureActionsAsync('exportInstances');

    const result = await this._sendAsync(
      {
        type: 'exportInstances',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: { paths },
      },
      DEFAULT_TIMEOUTS.exportInstances
    );

    if (result.type === 'exportInstancesResult') {
      return { data: result.payload.data, instances: result.payload.instances };
    }

    throw pluginError('exportInstancesResult', result);
  }

  /** Insert a binary model (.rbxm), base64-encoded, under `parentPath`. */
  async importInstancesAsync(
    data: string,
    parentPath: string
  ): Promise<ImportInstancesResult> {
    this._assertConnected();
    await this._ensureActionsAsync('importInstances');

    const result = await this._sendAsync(
      {
        type: 'importInstances',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: { data, parentPath },
      },
      DEFAULT_TIMEOUTS.importInstances
    );

    if (result.type === 'importInstancesResult') {
      return { instances: result.payload.instances };
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
    players?: number,
    bridge?: PlaytestBridgePayload
  ): Promise<PlaytestEndResult> {
    this._assertConnected();
    await this._ensureActionsAsync('startPlaytest');

    const result = await this._sendAsync(
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
          ...(bridge ? { bridge } : {}),
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
    await this._ensureActionsAsync('endPlaytest');

    const result = await this._sendAsync(
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

  /**
   * Read or change the players of the playtest this session belongs to.
   * `timeoutMs` bounds the whole request, including any wait in the plugin.
   */
  async playtestPlayersAsync(
    request: PlaytestPlayersRequest,
    timeoutMs: number
  ): Promise<PlaytestPlayersResult> {
    this._assertConnected();
    await this._ensureActionsAsync('playtestPlayers');

    const result = await this._sendAsync(
      {
        type: 'playtestPlayers',
        sessionId: this._info.sessionId,
        requestId: randomUUID(),
        payload: request,
      },
      timeoutMs
    );

    if (result.type === 'playtestPlayersResult') {
      return {
        players: result.payload.players ?? [],
        remaining: result.payload.remaining ?? [],
      };
    }

    throw pluginError('playtestPlayersResult', result);
  }

  private async _sendAsync(
    message: ServerMessage,
    timeoutMs: number
  ): Promise<PluginMessage> {
    let reply: PluginMessage;
    try {
      reply = await this._handle.sendActionAsync<PluginMessage>(
        message,
        timeoutMs
      );
    } catch (err) {
      if (err instanceof RequestTimeoutError) {
        throw new ActionTimeoutError(
          message.type,
          timeoutMs,
          this._info.sessionId
        );
      }
      if (!(err instanceof StudioBridgeError) && !this._handle.isConnected) {
        throw new SessionDisconnectedError(this._info.sessionId);
      }
      throw err;
    }
    if (reply.type === 'error' && reply.payload?.code === 'TIMEOUT') {
      throw new ActionTimeoutError(
        message.type,
        timeoutMs,
        this._info.sessionId
      );
    }
    return reply;
  }

  private _assertConnected(): void {
    if (!this._handle.isConnected) {
      throw new SessionDisconnectedError(this._info.sessionId);
    }
  }

  private async _ensureActionsAsync(messageType: string): Promise<void> {
    await this._syncActionsAsync();

    const command = this._outdated.get(messageType);
    if (command === undefined || this._warnedOutdated.has(messageType)) return;
    this._warnedOutdated.add(messageType);
    warnUser(
      this.context === 'edit'
        ? {
            code: 'ACTION_OUTDATED',
            message: `Studio runs an older '${command}', since the update failed to load, so it may not do what this version does.`,
            fix: 'Run the command again with --verbose to see why it failed to load.',
          }
        : {
            code: 'ACTION_OUTDATED',
            message: `This playtest runs an older '${command}', so it may not do what this version does.`,
            fix: "Run 'studio-bridge playtest restart' to update it.",
          }
    );
  }

  /**
   * Ensure action modules are synced to the plugin before first use.
   * Uses syncActions to determine which actions need updating, then
   * registers only those that are missing or have changed hashes.
   */
  private async _syncActionsAsync(): Promise<void> {
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
    const syncResult = await this._sendAsync(
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

      const failed = (syncResult.payload.failed ?? {}) as Record<
        string,
        FailedActionInfo
      >;

      const neededSet = new Set(needed);
      for (const action of this._actionSources) {
        const failedAction = failed[action.name];
        if (failedAction) {
          this._markOutdated(action, failedAction.handlers);
          OutputHelper.verbose(
            `[actions]   ${action.name}: FAILED earlier: ${failedAction.error}`
          );
          continue;
        }
        if (!neededSet.has(action.name)) continue;
        const actionName = action.name;

        OutputHelper.verbose(`[actions] Registering action: ${actionName}`);
        const regResult = await this._sendAsync(
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
          if (p.outdated) {
            this._markOutdated(action, p.handlers);
          }
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

  private _markOutdated(action: ActionSource, handlers: string[] | undefined) {
    for (const handler of handlers ?? []) {
      this._outdated.set(handler, toCommandName(action));
    }
  }
}

function toCommandName(action: ActionSource): string {
  return action.relativePath.split(/[\\/]/).slice(0, -1).join(' ');
}

function _formatMiB(bytes: number): string {
  return `${(bytes / (1024 * 1024)).toFixed(1)} MiB`;
}
