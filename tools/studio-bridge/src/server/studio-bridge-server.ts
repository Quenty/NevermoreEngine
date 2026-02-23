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
import * as fs from 'fs';
import * as http from 'http';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { WebSocketServer, type WebSocket } from 'ws';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  BuildContext,
  resolvePackagePath,
  resolveTemplatePath,
} from '@quenty/nevermore-template-helpers';
import {
  type OutputLevel,
  type Capability,
  type PluginMessage,
  type ServerMessage,
  encodeMessage,
  decodePluginMessage,
} from './web-socket-protocol.js';
import { ActionDispatcher } from './action-dispatcher.js';
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

/** Read the package version from package.json at startup. */
function readServerVersion(): string {
  try {
    const thisDir = path.dirname(fileURLToPath(import.meta.url));
    // Walk up from src/server/ to package root
    const pkgPath = path.resolve(thisDir, '..', '..', 'package.json');
    const raw = fs.readFileSync(pkgPath, 'utf-8');
    const pkg = JSON.parse(raw) as { version?: string };
    return pkg.version ?? '0.0.0';
  } catch {
    return '0.0.0';
  }
}

const SERVER_VERSION = readServerVersion();

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
 * Create an HTTP server with health endpoint and a noServer WebSocket server.
 * The HTTP server handles `GET /health` and 404 for other paths. WebSocket
 * upgrades to `/${sessionId}` are forwarded to the WSS; others are rejected.
 *
 * Returns the assigned port once listening.
 */
function startHttpAndWsServerAsync(
  httpServer: http.Server,
  wss: WebSocketServer,
  sessionId: string,
): Promise<number> {
  // Handle normal HTTP requests
  httpServer.on('request', (req: http.IncomingMessage, res: http.ServerResponse) => {
    if (req.method === 'GET' && req.url === '/health') {
      const addr = httpServer.address();
      const port = typeof addr === 'object' && addr !== null ? addr.port : 0;
      const body = JSON.stringify({
        status: 'ok',
        sessionId,
        port,
        protocolVersion: 2,
        serverVersion: SERVER_VERSION,
      });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(body);
      return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  });

  // Handle WebSocket upgrades — only allow /${sessionId}
  httpServer.on('upgrade', (req: http.IncomingMessage, socket: import('stream').Duplex, head: Buffer) => {
    const expectedPath = `/${sessionId}`;
    if (req.url !== expectedPath) {
      socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
      socket.destroy();
      return;
    }

    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit('connection', ws, req);
    });
  });

  return new Promise((resolve, reject) => {
    httpServer.on('error', reject);
    httpServer.listen(0, () => {
      const addr = httpServer.address();
      if (typeof addr === 'object' && addr !== null) {
        resolve(addr.port);
      } else {
        reject(new Error('HTTP server address is not available'));
      }
    });
  });
}

/**
 * Maps action types to the capability required to perform them.
 * Used by performActionAsync to validate the plugin supports the action.
 */
const ACTION_CAPABILITIES: Record<string, Capability> = {
  queryState: 'queryState',
  captureScreenshot: 'captureScreenshot',
  queryDataModel: 'queryDataModel',
  queryLogs: 'queryLogs',
  subscribe: 'subscribe',
  unsubscribe: 'subscribe',
  execute: 'execute',
};

export class StudioBridgeServer {
  private _state: BridgeState = 'idle';

  private readonly _sessionId: string;
  private readonly _defaultTimeoutMs: number;
  private readonly _onPhase: ((phase: StudioBridgePhase) => void) | undefined;
  private readonly _placePath: string | undefined;

  private _httpServer: http.Server | undefined;
  private _wss: WebSocketServer | undefined;
  private _port: number = 0;
  private _pluginHandle: InjectedPlugin | undefined;
  private _studioProc: StudioProcess | undefined;
  private _placeBuildContext: BuildContext | undefined;
  private _connectedClient: WebSocket | undefined;

  private _negotiatedProtocolVersion: number = 1;
  private _negotiatedCapabilities: Capability[] = ['execute'];
  private _lastHeartbeatTimestamp: number | undefined;
  private _actionDispatcher = new ActionDispatcher();

  constructor(options: StudioBridgeServerOptions = {}) {
    this._sessionId = options.sessionId ?? randomUUID();
    this._defaultTimeoutMs = options.timeoutMs ?? 120_000;
    this._onPhase = options.onPhase;
    this._placePath = options.placePath;
  }

  // -----------------------------------------------------------------------
  // Public getters for negotiated protocol state
  // -----------------------------------------------------------------------

  /** The negotiated protocol version (1 for v1, 2 for v2 plugins). */
  get protocolVersion(): number {
    return this._negotiatedProtocolVersion;
  }

  /** The negotiated set of capabilities shared between plugin and server. */
  get capabilities(): readonly Capability[] {
    return this._negotiatedCapabilities;
  }

  // -----------------------------------------------------------------------
  // v2 action dispatch
  // -----------------------------------------------------------------------

  /**
   * Send a v2 protocol action to the connected plugin and wait for the
   * correlated response. Requires protocol version >= 2 and the relevant
   * capability to be negotiated.
   *
   * This is the v2 path -- the v1 `executeAsync` is unchanged.
   */
  async performActionAsync<T extends PluginMessage>(
    message: Omit<ServerMessage, 'requestId' | 'sessionId'>,
    timeoutMs?: number,
  ): Promise<T> {
    if (this._state !== 'ready') {
      throw new Error(
        `Cannot perform action: expected state 'ready', got '${this._state}'`,
      );
    }
    if (!this._connectedClient) {
      throw new Error('Cannot perform action: no connected client');
    }
    if (this._negotiatedProtocolVersion < 2) {
      throw new Error('Plugin does not support v2 actions');
    }

    // Validate capability
    const actionType = message.type;
    const requiredCapability = ACTION_CAPABILITIES[actionType];
    if (
      requiredCapability &&
      !this._negotiatedCapabilities.includes(requiredCapability)
    ) {
      throw new Error(`Plugin does not support capability: ${requiredCapability}`);
    }

    const { requestId, responsePromise } = this._actionDispatcher.createRequestAsync(
      actionType,
      timeoutMs,
    );

    const fullMessage: ServerMessage = {
      ...message,
      requestId,
      sessionId: this._sessionId,
    } as ServerMessage;

    this._connectedClient.send(encodeMessage(fullMessage));

    return responsePromise as Promise<T>;
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

      // 1. Start HTTP + WebSocket server (unique path rejects wrong connections at upgrade level)
      this._httpServer = http.createServer();
      this._wss = new WebSocketServer({ noServer: true });
      const port = await startHttpAndWsServerAsync(this._httpServer, this._wss, this._sessionId);
      this._port = port;
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
    // The full set of capabilities the server supports for negotiation.
    const serverSupportedCapabilities: Capability[] = [
      'execute',
      'queryState',
      'captureScreenshot',
      'queryDataModel',
      'queryLogs',
      'subscribe',
    ];

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
          if (!msg) {
            return;
          }

          if (msg.type === 'hello') {
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

            // Determine if this is a v2 hello (has protocolVersion in the raw message)
            let rawProtocolVersion: number | undefined;
            try {
              const rawObj = JSON.parse(data) as Record<string, unknown>;
              if (typeof rawObj.protocolVersion === 'number') {
                rawProtocolVersion = rawObj.protocolVersion;
              }
            } catch {
              // ignore parse errors, already decoded via decodePluginMessage
            }

            const isV2 = rawProtocolVersion !== undefined && rawProtocolVersion >= 2;

            if (isV2) {
              // v2 hello: negotiate protocol version and capabilities
              this._negotiatedProtocolVersion = Math.min(rawProtocolVersion!, 2);
              const pluginCapabilities = msg.payload.capabilities ?? ['execute' as Capability];
              this._negotiatedCapabilities = pluginCapabilities.filter(
                (cap) => serverSupportedCapabilities.includes(cap),
              );

              OutputHelper.verbose('[StudioBridge] v2 handshake accepted');
              const welcomePayload: Record<string, unknown> = {
                sessionId: this._sessionId,
                protocolVersion: this._negotiatedProtocolVersion,
                capabilities: this._negotiatedCapabilities,
              };
              ws.send(JSON.stringify({
                type: 'welcome',
                sessionId: this._sessionId,
                payload: welcomePayload,
              }));
            } else {
              // v1 hello: no protocol version or capabilities in welcome
              this._negotiatedProtocolVersion = 1;
              this._negotiatedCapabilities = ['execute'];

              OutputHelper.verbose('[StudioBridge] Handshake accepted');
              ws.send(
                encodeMessage({
                  type: 'welcome',
                  sessionId: this._sessionId,
                  payload: { sessionId: this._sessionId },
                })
              );
            }

            ws.off('message', onMessage);
            this._finishHandshake(ws, settled, timer, resolve);
            settled = true;
            return;
          }

          if (msg.type === 'register') {
            // Always v2
            this._negotiatedProtocolVersion = Math.min(msg.protocolVersion, 2);
            this._negotiatedCapabilities = msg.payload.capabilities.filter(
              (cap) => serverSupportedCapabilities.includes(cap),
            );

            OutputHelper.verbose('[StudioBridge] v2 register handshake accepted');
            const welcomePayload: Record<string, unknown> = {
              sessionId: this._sessionId,
              protocolVersion: this._negotiatedProtocolVersion,
              capabilities: this._negotiatedCapabilities,
            };
            ws.send(JSON.stringify({
              type: 'welcome',
              sessionId: this._sessionId,
              payload: welcomePayload,
            }));

            ws.off('message', onMessage);
            this._finishHandshake(ws, settled, timer, resolve);
            settled = true;
            return;
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

  /**
   * Common handshake completion: store the connected client, listen for
   * heartbeats and disconnect events.
   */
  private _finishHandshake(
    ws: WebSocket,
    alreadySettled: boolean,
    timer: ReturnType<typeof setTimeout>,
    resolve: () => void,
  ): void {
    this._connectedClient = ws;

    // Listen for all post-handshake messages: route through action dispatcher
    // first, then handle heartbeats and other messages.
    ws.on('message', (raw: Buffer | string) => {
      const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
      const msg = decodePluginMessage(data);
      if (!msg) return;

      // Try action dispatcher first (v2 request/response correlation)
      if (this._actionDispatcher.handleResponse(msg)) {
        return;
      }

      // Heartbeat handling
      if (msg.type === 'heartbeat') {
        this._lastHeartbeatTimestamp = Date.now();
      }
    });

    // Listen for unexpected disconnect
    ws.on('close', () => {
      OutputHelper.verbose('[StudioBridge] Plugin disconnected');
      this._connectedClient = undefined;
      if (this._state !== 'stopping' && this._state !== 'stopped') {
        this._state = 'stopped';
      }
    });

    if (!alreadySettled) {
      clearTimeout(timer);
      resolve();
    }
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
    // Cancel all pending v2 action requests
    this._actionDispatcher.cancelAll('Server shutting down');

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

    // Terminate lingering WebSocket connections first so close callbacks
    // fire promptly, then close the HTTP server (which owns the listening
    // socket) and finally close the WSS.
    if (this._wss) {
      for (const wsClient of this._wss.clients) {
        wsClient.terminate();
      }
      await new Promise<void>((resolve) => {
        this._wss!.close(() => resolve());
      });
      this._wss = undefined;
    }

    if (this._httpServer) {
      await new Promise<void>((resolve) => {
        this._httpServer!.close(() => resolve());
      });
      this._httpServer = undefined;
    }

    this._connectedClient = undefined;
  }
}
