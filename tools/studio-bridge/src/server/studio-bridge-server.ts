/**
 * Main orchestrator — starts a WebSocket server, injects the Studio plugin,
 * launches Studio, and waits for script execution to complete.
 *
 * Lifecycle:
 *   const server = new StudioBridgeServer({ placePath, timeoutMs, onPhase });
 *   await server.startAsync();
 *   const result = await server.executeAsync({ scriptContent, onOutput });
 *   await server.stopAsync();
 */

import { randomUUID } from 'crypto';
import * as path from 'path';
import { WebSocketServer, type WebSocket } from 'ws';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  BuildContext,
  resolvePackagePath,
  resolveTemplatePath,
} from '@quenty/nevermore-template-helpers';
import {
  type OutputLevel,
  encodeMessage,
  decodePluginMessage,
} from './web-socket-protocol.js';
import {
  injectPluginAsync,
  type InjectedPlugin,
} from '../plugin/plugin-injector.js';
import {
  launchStudioAsync,
  type StudioProcess,
} from '../process/studio-process-manager.js';

const defaultProjectPath = resolveTemplatePath(
  import.meta.url,
  path.join('default-test-place', 'default.project.json')
);

const sessionAttributeTransformScript = resolvePackagePath(
  import.meta.url,
  'build-scripts',
  'transform-add-session-attribute.luau'
);

// ---------------------------------------------------------------------------
// Public API types
// ---------------------------------------------------------------------------

export type StudioBridgePhase =
  | 'building'
  | 'launching'
  | 'connecting'
  | 'executing'
  | 'done';

export interface StudioBridgeServerOptions {
  /** Path to the .rbxl place file to open. If omitted, a minimal place is
   *  built automatically via rojo (requires rojo on PATH). */
  placePath?: string;
  /** Default timeout in ms for operations (default: 120_000) */
  timeoutMs?: number;
  /** Callback for progress phases (building, launching, connecting, executing, done) */
  onPhase?: (phase: StudioBridgePhase) => void;
  /** Session ID for concurrent session isolation. Auto-generated if omitted. */
  sessionId?: string;
}

export interface ExecuteOptions {
  /** Luau script content to execute */
  scriptContent: string;
  /** Timeout in ms for this execution (overrides default) */
  timeoutMs?: number;
  /** Callback for each output message */
  onOutput?: (level: OutputLevel, body: string) => void;
}

export interface StudioBridgeResult {
  success: boolean;
  logs: string;
}

// ---------------------------------------------------------------------------
// State machine
// ---------------------------------------------------------------------------

type BridgeState =
  | 'idle'
  | 'starting'
  | 'ready'
  | 'executing'
  | 'stopping'
  | 'stopped';

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

/**
 * Start a WebSocket server on a random available port and return the assigned
 * port number once listening.
 */
function startWsServerAsync(wss: WebSocketServer): Promise<number> {
  return new Promise((resolve, reject) => {
    wss.on('error', reject);
    wss.on('listening', () => {
      const addr = wss.address();
      if (typeof addr === 'object' && addr !== null) {
        resolve(addr.port);
      } else {
        reject(new Error('WebSocket server address is not available'));
      }
    });
  });
}

export class StudioBridgeServer {
  private _state: BridgeState = 'idle';

  private readonly _sessionId: string;
  private readonly _defaultTimeoutMs: number;
  private readonly _onPhase: ((phase: StudioBridgePhase) => void) | undefined;
  private readonly _placePath: string | undefined;

  private _wss: WebSocketServer | undefined;
  private _pluginHandle: InjectedPlugin | undefined;
  private _studioProc: StudioProcess | undefined;
  private _placeBuildContext: BuildContext | undefined;
  private _connectedClient: WebSocket | undefined;

  constructor(options: StudioBridgeServerOptions = {}) {
    this._sessionId = options.sessionId ?? randomUUID();
    this._defaultTimeoutMs = options.timeoutMs ?? 120_000;
    this._onPhase = options.onPhase;
    this._placePath = options.placePath;
  }

  // -----------------------------------------------------------------------
  // Lifecycle: startAsync
  // -----------------------------------------------------------------------

  /**
   * Build place (if needed) → start WS server → inject plugin → launch
   * Studio → wait for handshake.
   */
  async startAsync(): Promise<void> {
    if (this._state !== 'idle') {
      throw new Error(
        `Cannot start: expected state 'idle', got '${this._state}'`
      );
    }
    this._state = 'starting';

    try {
      this._placeBuildContext = await BuildContext.createAsync({
        prefix: 'studio-bridge-',
      });

      // 0. Build a minimal place if none was provided
      let placePath = this._placePath;
      if (!placePath) {
        this._onPhase?.('building');
        const builtPlacePath =
          this._placeBuildContext.resolvePath('minimal.rbxl');
        await this._placeBuildContext.rojoBuildAsync({
          projectPath: defaultProjectPath,
          output: builtPlacePath,
        });
        placePath = builtPlacePath;
      }

      // 0b. Stamp session ID attribute onto the place file
      const transformedPlacePath = this._placeBuildContext.resolvePath(
        'studio-bridge-with-session-id.rbxl'
      );
      await this._placeBuildContext.executeLuneTransformScriptAsync(
        sessionAttributeTransformScript,
        placePath,
        transformedPlacePath,
        this._sessionId
      );
      placePath = transformedPlacePath;

      // 1. Start WebSocket server (unique path rejects wrong connections at HTTP upgrade level)
      this._wss = new WebSocketServer({ port: 0, path: `/${this._sessionId}` });
      const port = await startWsServerAsync(this._wss);
      OutputHelper.verbose(
        `[StudioBridge] WebSocket server listening on port ${port}`
      );

      // 2. Inject plugin (no scriptContent — scripts are sent via execute messages)
      this._pluginHandle = await injectPluginAsync({
        port,
        sessionId: this._sessionId,
      });
      OutputHelper.verbose(
        `[StudioBridge] Plugin injected: ${this._pluginHandle.pluginPath}`
      );

      // 3. Launch Studio
      this._onPhase?.('launching');
      this._studioProc = await launchStudioAsync(placePath);
      OutputHelper.verbose(
        `[StudioBridge] Studio launched (PID: ${this._studioProc.process.pid})`
      );

      // 4. Wait for handshake
      this._onPhase?.('connecting');
      await this._waitForHandshakeAsync();

      this._state = 'ready';
    } catch (error) {
      await this._cleanupResourcesAsync();
      this._state = 'stopped';
      throw error;
    }
  }

  // -----------------------------------------------------------------------
  // Lifecycle: executeAsync
  // -----------------------------------------------------------------------

  /**
   * Send a Luau script to the connected Studio instance and wait for it to
   * finish executing. Can be called multiple times while the bridge is ready.
   */
  async executeAsync(options: ExecuteOptions): Promise<StudioBridgeResult> {
    if (this._state !== 'ready') {
      throw new Error(
        `Cannot execute: expected state 'ready', got '${this._state}'`
      );
    }
    if (!this._connectedClient) {
      throw new Error('Cannot execute: no connected client');
    }

    this._state = 'executing';
    this._onPhase?.('executing');

    try {
      // Send execute message
      this._connectedClient.send(
        encodeMessage({
          type: 'execute',
          sessionId: this._sessionId,
          payload: { script: options.scriptContent },
        })
      );

      // Wait for result
      const result = await this._waitForScriptCompleteAsync(options);

      this._onPhase?.('done');
      this._state = 'ready';
      return result;
    } catch (error) {
      // If we errored during execution, we may still be usable or not.
      // If the client disconnected, state will already be 'stopped'.
      if (this._state === 'executing') {
        this._state = 'ready';
      }
      throw error;
    }
  }

  // -----------------------------------------------------------------------
  // Lifecycle: stopAsync
  // -----------------------------------------------------------------------

  /**
   * Shut down the bridge — send shutdown to client, kill Studio, clean up
   * all resources. Idempotent on 'stopped'.
   */
  async stopAsync(): Promise<void> {
    if (this._state === 'stopped') {
      return;
    }

    this._state = 'stopping';

    // Send shutdown to connected client
    if (this._connectedClient) {
      try {
        this._connectedClient.send(
          encodeMessage({
            type: 'shutdown',
            sessionId: this._sessionId,
            payload: {},
          })
        );
      } catch {
        // ignore
      }
    }

    await this._cleanupResourcesAsync();
    this._state = 'stopped';
  }

  // -----------------------------------------------------------------------
  // Private: _waitForHandshakeAsync
  // -----------------------------------------------------------------------

  private _waitForHandshakeAsync(): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      let settled = false;

      const timer = setTimeout(() => {
        if (!settled) {
          settled = true;
          reject(
            new Error(
              `Timed out waiting for Studio plugin handshake after ${this._defaultTimeoutMs}ms`
            )
          );
        }
      }, this._defaultTimeoutMs);

      this._wss!.on('connection', (ws: WebSocket) => {
        OutputHelper.verbose('[StudioBridge] Plugin connected');

        const onMessage = (raw: Buffer | string) => {
          const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
          const msg = decodePluginMessage(data);
          if (!msg || msg.type !== 'hello') {
            return;
          }

          if (
            msg.sessionId !== this._sessionId ||
            msg.payload.sessionId !== this._sessionId
          ) {
            OutputHelper.verbose(
              `[StudioBridge] Rejecting hello with wrong session ID`
            );
            ws.close();
            return;
          }

          // Handshake accepted
          OutputHelper.verbose('[StudioBridge] Handshake accepted');
          ws.send(
            encodeMessage({
              type: 'welcome',
              sessionId: this._sessionId,
              payload: { sessionId: this._sessionId },
            })
          );

          ws.off('message', onMessage);
          this._connectedClient = ws;

          // Listen for unexpected disconnect
          ws.on('close', () => {
            OutputHelper.verbose('[StudioBridge] Plugin disconnected');
            this._connectedClient = undefined;
            if (this._state !== 'stopping' && this._state !== 'stopped') {
              this._state = 'stopped';
            }
          });

          if (!settled) {
            settled = true;
            clearTimeout(timer);
            resolve();
          }
        };

        ws.on('message', onMessage);

        ws.on('error', (err) => {
          OutputHelper.verbose(
            `[StudioBridge] WebSocket error: ${err.message}`
          );
        });
      });

      this._wss!.on('error', (err) => {
        if (!settled) {
          settled = true;
          clearTimeout(timer);
          reject(err);
        }
      });
    });
  }

  // -----------------------------------------------------------------------
  // Private: _waitForScriptCompleteAsync
  // -----------------------------------------------------------------------

  private _waitForScriptCompleteAsync(
    options: ExecuteOptions
  ): Promise<StudioBridgeResult> {
    const timeoutMs = options.timeoutMs ?? this._defaultTimeoutMs;
    const logLines: string[] = [];
    const ws = this._connectedClient!;

    return new Promise<StudioBridgeResult>((resolve, reject) => {
      let settled = false;

      const timer = setTimeout(() => {
        if (!settled) {
          settled = true;
          cleanup();
          resolve({
            success: false,
            logs: [
              ...logLines,
              `[StudioBridge] Timed out after ${timeoutMs}ms`,
            ].join('\n'),
          });
        }
      }, timeoutMs);

      const finish = (result: StudioBridgeResult) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        cleanup();
        resolve(result);
      };

      const onMessage = (raw: Buffer | string) => {
        const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
        const msg = decodePluginMessage(data);
        if (!msg) {
          OutputHelper.verbose(
            `[StudioBridge] Ignoring malformed message: ${data.slice(0, 200)}`
          );
          return;
        }

        if (msg.sessionId !== this._sessionId) {
          OutputHelper.verbose(
            `[StudioBridge] Ignoring message with wrong session ID`
          );
          return;
        }

        switch (msg.type) {
          case 'output': {
            for (const entry of msg.payload.messages) {
              logLines.push(entry.body);
              options.onOutput?.(entry.level, entry.body);
            }
            break;
          }

          case 'scriptComplete': {
            OutputHelper.verbose(
              `[StudioBridge] Script complete: success=${msg.payload.success}` +
                (msg.payload.error ? ` error=${msg.payload.error}` : '')
            );

            if (msg.payload.error) {
              logLines.push(msg.payload.error);
            }

            finish({
              success: msg.payload.success,
              logs: logLines.join('\n'),
            });
            break;
          }
        }
      };

      const onClose = () => {
        if (!settled) {
          finish({
            success: false,
            logs: [
              ...logLines,
              '[StudioBridge] Plugin disconnected before script completed',
            ].join('\n'),
          });
        }
      };

      const onError = (err: Error) => {
        OutputHelper.verbose(`[StudioBridge] WebSocket error: ${err.message}`);
      };

      const cleanup = () => {
        ws.off('message', onMessage);
        ws.off('close', onClose);
        ws.off('error', onError);
      };

      ws.on('message', onMessage);
      ws.on('close', onClose);
      ws.on('error', onError);
    });
  }

  // -----------------------------------------------------------------------
  // Private: _cleanupResourcesAsync
  // -----------------------------------------------------------------------

  private async _cleanupResourcesAsync(): Promise<void> {
    // Kill Studio
    if (this._studioProc) {
      await this._studioProc.killAsync();
      this._studioProc = undefined;
    }

    // Remove injected plugin
    if (this._pluginHandle) {
      await this._pluginHandle.cleanupAsync();
      this._pluginHandle = undefined;
    }

    // Remove auto-built place
    if (this._placeBuildContext) {
      await this._placeBuildContext.cleanupAsync();
      this._placeBuildContext = undefined;
    }

    // Close WebSocket server — terminate lingering connections first so
    // the 'close' callback fires promptly.
    if (this._wss) {
      for (const wsClient of this._wss.clients) {
        wsClient.terminate();
      }
      await new Promise<void>((resolve) => {
        this._wss!.close(() => resolve());
      });
      this._wss = undefined;
    }

    this._connectedClient = undefined;
  }
}
