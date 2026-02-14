/**
 * Main orchestrator — starts a WebSocket server, injects the Studio plugin,
 * launches Studio, and waits for script execution to complete.
 */

import { randomUUID } from 'crypto';
import { WebSocketServer, type WebSocket } from 'ws';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type PluginMessage,
  type OutputLevel,
  encodeMessage,
  decodePluginMessage,
} from './protocol.js';
import { injectPluginAsync, type InjectedPlugin } from './plugin-injector.js';
import { launchStudioAsync, type StudioProcess } from './studio-process.js';
import { buildMinimalPlaceAsync, type BuiltPlace } from './place-builder.js';

// ---------------------------------------------------------------------------
// Public API types
// ---------------------------------------------------------------------------

export type StudioBridgePhase = 'building' | 'launching' | 'connecting' | 'executing' | 'done';

export interface StudioBridgeOptions {
  /** Path to the .rbxl place file to open. If omitted, a minimal place is
   *  built automatically via rojo (requires rojo on PATH). */
  placePath?: string;
  /** Luau script content to execute */
  scriptContent: string;
  /** Timeout in ms (default: 120_000) */
  timeoutMs?: number;
  /** Callback for each output message */
  onOutput?: (level: OutputLevel, body: string) => void;
  /** Callback for progress phases (building, launching, connecting, executing, done) */
  onPhase?: (phase: StudioBridgePhase) => void;
}

export interface StudioBridgeResult {
  success: boolean;
  logs: string;
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

/**
 * Start a WebSocket server on a random available port and return the assigned
 * port number once listening.
 */
function startServerAsync(wss: WebSocketServer): Promise<number> {
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

export class StudioBridge {
  /**
   * Run a Luau script in Roblox Studio and return when execution completes.
   *
   * Flow:
   *  1. Start WebSocket server on an OS-assigned port
   *  2. Inject a plugin .rbxmx into Studio's plugins folder
   *  3. Launch Studio with the place file
   *  4. Wait for the plugin to connect and send `hello`
   *  5. Stream output back via `onOutput` callback
   *  6. Wait for `scriptComplete`
   *  7. Clean up (kill Studio, delete plugin, close server)
   */
  static async executeAsync(options: StudioBridgeOptions): Promise<StudioBridgeResult> {
    const {
      scriptContent,
      timeoutMs = 120_000,
      onOutput,
      onPhase,
    } = options;

    const sessionId = randomUUID();
    const logLines: string[] = [];
    let builtPlace: BuiltPlace | undefined;
    let pluginHandle: InjectedPlugin | undefined;
    let studioProc: StudioProcess | undefined;
    let wss: WebSocketServer | undefined;

    const cleanup = async () => {
      // Send shutdown to connected client
      if (wss) {
        for (const client of wss.clients) {
          try {
            client.send(encodeMessage({ type: 'shutdown', payload: {} }));
          } catch {
            // ignore
          }
        }
      }

      // Kill Studio
      if (studioProc) {
        await studioProc.killAsync();
      }

      // Remove injected plugin
      if (pluginHandle) {
        await pluginHandle.cleanupAsync();
      }

      // Remove auto-built place
      if (builtPlace) {
        await builtPlace.cleanupAsync();
      }

      // Close WebSocket server
      if (wss) {
        await new Promise<void>((resolve) => {
          wss!.close(() => resolve());
        });
      }
    };

    try {
      // 0. Build a minimal place if none was provided
      let placePath = options.placePath;
      if (!placePath) {
        onPhase?.('building');
        builtPlace = await buildMinimalPlaceAsync();
        placePath = builtPlace.placePath;
      }

      // 1. Start WebSocket server
      wss = new WebSocketServer({ port: 0 });
      const port = await startServerAsync(wss);
      OutputHelper.verbose(`[StudioBridge] WebSocket server listening on port ${port}`);

      // 2. Inject plugin
      pluginHandle = await injectPluginAsync({
        port,
        sessionId,
        scriptContent,
      });
      OutputHelper.verbose(`[StudioBridge] Plugin injected: ${pluginHandle.pluginPath}`);

      // 3. Launch Studio
      onPhase?.('launching');
      studioProc = await launchStudioAsync(placePath);
      OutputHelper.verbose(`[StudioBridge] Studio launched (PID: ${studioProc.process.pid})`);

      // 4–6. Wait for plugin connection + script execution
      onPhase?.('connecting');
      const result = await waitForExecutionAsync({
        wss,
        sessionId,
        timeoutMs,
        onOutput,
        onPhase,
        logLines,
      });

      return result;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return {
        success: false,
        logs: [...logLines, `[StudioBridge] Error: ${errorMessage}`].join('\n'),
      };
    } finally {
      await cleanup();
    }
  }
}

// ---------------------------------------------------------------------------
// Internal: wait for the full plugin lifecycle
// ---------------------------------------------------------------------------

interface WaitOptions {
  wss: WebSocketServer;
  sessionId: string;
  timeoutMs: number;
  onOutput?: (level: OutputLevel, body: string) => void;
  onPhase?: (phase: StudioBridgePhase) => void;
  logLines: string[];
}

function waitForExecutionAsync(options: WaitOptions): Promise<StudioBridgeResult> {
  const { wss, sessionId, timeoutMs, onOutput, onPhase, logLines } = options;

  return new Promise<StudioBridgeResult>((resolve, reject) => {
    let settled = false;

    const timer = setTimeout(() => {
      if (!settled) {
        settled = true;
        resolve({
          success: false,
          logs: [...logLines, `[StudioBridge] Timed out after ${timeoutMs}ms`].join('\n'),
        });
      }
    }, timeoutMs);

    const finish = (result: StudioBridgeResult) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(result);
    };

    wss.on('connection', (ws: WebSocket) => {
      OutputHelper.verbose('[StudioBridge] Plugin connected');

      ws.on('message', (raw: Buffer | string) => {
        const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
        const msg = decodePluginMessage(data);
        if (!msg) {
          OutputHelper.verbose(`[StudioBridge] Ignoring malformed message: ${data.slice(0, 200)}`);
          return;
        }

        handleMessage(ws, msg, sessionId, onOutput, onPhase, logLines, finish);
      });

      ws.on('close', () => {
        OutputHelper.verbose('[StudioBridge] Plugin disconnected');
        // If the plugin disconnects before sending scriptComplete, treat as failure
        if (!settled) {
          finish({
            success: false,
            logs: [...logLines, '[StudioBridge] Plugin disconnected before script completed'].join(
              '\n'
            ),
          });
        }
      });

      ws.on('error', (err) => {
        OutputHelper.verbose(`[StudioBridge] WebSocket error: ${err.message}`);
      });
    });

    wss.on('error', (err) => {
      if (!settled) {
        settled = true;
        clearTimeout(timer);
        reject(err);
      }
    });
  });
}

function handleMessage(
  ws: WebSocket,
  msg: PluginMessage,
  sessionId: string,
  onOutput: ((level: OutputLevel, body: string) => void) | undefined,
  onPhase: ((phase: StudioBridgePhase) => void) | undefined,
  logLines: string[],
  finish: (result: StudioBridgeResult) => void
): void {
  switch (msg.type) {
    case 'hello': {
      if (msg.payload.sessionId !== sessionId) {
        OutputHelper.verbose(
          `[StudioBridge] Ignoring hello with wrong session ID: ${msg.payload.sessionId}`
        );
        return;
      }
      OutputHelper.verbose('[StudioBridge] Handshake accepted');
      ws.send(encodeMessage({ type: 'welcome', payload: { sessionId } }));
      onPhase?.('executing');
      break;
    }

    case 'output': {
      for (const entry of msg.payload.messages) {
        logLines.push(entry.body);
        onOutput?.(entry.level, entry.body);
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

      onPhase?.('done');
      finish({
        success: msg.payload.success,
        logs: logLines.join('\n'),
      });
      break;
    }
  }
}
