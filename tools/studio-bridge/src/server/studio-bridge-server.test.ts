/**
 * Unit tests for StudioBridgeServer — validates the lifecycle state machine,
 * WebSocket handshake, execute-message protocol, multi-execution reuse,
 * timeout handling, and cleanup. External dependencies (plugin injection,
 * Studio launch, place building) are mocked so no file I/O or processes are
 * needed.
 */

import { describe, it, expect, vi, afterEach } from 'vitest';
import { WebSocket } from 'ws';
import { StudioBridgeServer, type StudioBridgePhase } from './studio-bridge-server.js';

// ---------------------------------------------------------------------------
// Mocks — replace external side-effects with no-ops
// ---------------------------------------------------------------------------

vi.mock('../plugin/plugin-injector.js', () => ({
  injectPluginAsync: vi.fn(async () => ({
    pluginPath: '/fake/plugin.rbxmx',
    cleanupAsync: vi.fn(async () => {}),
  })),
}));

vi.mock('../process/studio-process-manager.js', () => ({
  launchStudioAsync: vi.fn(async () => ({
    process: { pid: 12345 },
    killAsync: vi.fn(async () => {}),
  })),
  findPluginsFolder: vi.fn(() => '/fake/plugins'),
}));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Connect a WebSocket client to the server and perform the hello/welcome
 * handshake, returning the connected client.
 */
async function connectAndHandshake(
  port: number,
  sessionId: string
): Promise<WebSocket> {
  const ws = new WebSocket(`ws://localhost:${port}`);

  await new Promise<void>((resolve, reject) => {
    ws.on('open', resolve);
    ws.on('error', reject);
  });

  // Send hello
  ws.send(JSON.stringify({ type: 'hello', payload: { sessionId } }));

  // Wait for welcome
  await new Promise<void>((resolve) => {
    ws.on('message', (raw) => {
      const data = JSON.parse(
        typeof raw === 'string' ? raw : raw.toString('utf-8')
      );
      if (data.type === 'welcome') {
        resolve();
      }
    });
  });

  return ws;
}

/**
 * Create a StudioBridgeServer with a known sessionId, start it by simulating
 * a plugin client connecting. Returns the server, the simulated client WS,
 * and the port.
 */
async function createReadyServer(
  options: { sessionId?: string; timeoutMs?: number; onPhase?: (p: StudioBridgePhase) => void } = {}
) {
  const sessionId = options.sessionId ?? 'test-session';
  const server = new StudioBridgeServer({
    placePath: '/fake/place.rbxl',
    sessionId,
    timeoutMs: options.timeoutMs ?? 5_000,
    onPhase: options.onPhase,
  });

  // Start in background — it will wait for handshake
  const startPromise = server.startAsync();

  // We need to discover the port the server is listening on. The WSS is
  // created inside startAsync and we can't access it directly. However, we
  // know the mock for launchStudioAsync will resolve immediately, so the
  // server will be waiting for a handshake. We just need the port.
  // Access it via the private field (acceptable in tests).
  // Wait a tick for the WSS to be created
  await new Promise((r) => setTimeout(r, 50));
  const wss = (server as any)._wss;
  const addr = wss.address();
  const port: number = addr.port;

  // Simulate plugin connecting and performing handshake
  const client = await connectAndHandshake(port, sessionId);

  // Now startAsync should resolve
  await startPromise;

  return { server, client, port, sessionId };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('StudioBridgeServer', () => {
  let server: StudioBridgeServer | undefined;
  let client: WebSocket | undefined;

  afterEach(async () => {
    // Clean up any open connections
    if (client && client.readyState === WebSocket.OPEN) {
      client.close();
    }
    if (server) {
      await server.stopAsync();
    }
    client = undefined;
    server = undefined;
  });

  // -----------------------------------------------------------------------
  // State machine guards
  // -----------------------------------------------------------------------

  describe('state guards', () => {
    it('throws when executeAsync is called before startAsync', async () => {
      server = new StudioBridgeServer({ placePath: '/fake/place.rbxl' });
      await expect(
        server.executeAsync({ scriptContent: 'print("hi")' })
      ).rejects.toThrow("Cannot execute: expected state 'ready', got 'idle'");
    });

    it('throws when startAsync is called twice', async () => {
      const ready = await createReadyServer();
      server = ready.server;
      client = ready.client;

      await expect(server.startAsync()).rejects.toThrow(
        "Cannot start: expected state 'idle', got 'ready'"
      );
    });

    it('stopAsync is idempotent', async () => {
      const ready = await createReadyServer();
      server = ready.server;
      client = ready.client;

      await server.stopAsync();
      // Second call should not throw
      await server.stopAsync();
    });
  });

  // -----------------------------------------------------------------------
  // Handshake
  // -----------------------------------------------------------------------

  describe('handshake', () => {
    it('accepts hello with correct session ID and sends welcome', async () => {
      const ready = await createReadyServer({ sessionId: 'my-session' });
      server = ready.server;
      client = ready.client;

      // If we got here, the handshake succeeded (connectAndHandshake waits
      // for the welcome message)
      expect(true).toBe(true);
    });

    it('ignores hello with wrong session ID', async () => {
      const sessionId = 'correct-session';
      server = new StudioBridgeServer({
        placePath: '/fake/place.rbxl',
        sessionId,
        timeoutMs: 1_000,
      });

      const startPromise = server.startAsync();

      await new Promise((r) => setTimeout(r, 50));
      const wss = (server as any)._wss;
      const port: number = wss.address().port;

      // Connect with wrong session ID
      const ws = new WebSocket(`ws://localhost:${port}`);
      await new Promise<void>((resolve, reject) => {
        ws.on('open', resolve);
        ws.on('error', reject);
      });

      ws.send(
        JSON.stringify({
          type: 'hello',
          payload: { sessionId: 'wrong-session' },
        })
      );

      // Server should NOT accept — startAsync should time out
      await expect(startPromise).rejects.toThrow('Timed out waiting for Studio plugin handshake');

      ws.close();
      // Server already stopped on failure (startAsync catch cleans up)
    });
  });

  // -----------------------------------------------------------------------
  // Script execution
  // -----------------------------------------------------------------------

  describe('executeAsync', () => {
    it('sends execute message and returns result on scriptComplete', async () => {
      const ready = await createReadyServer();
      server = ready.server;
      client = ready.client;

      // Listen for execute message from server
      const executePromise = new Promise<string>((resolve) => {
        client!.on('message', (raw) => {
          const data = JSON.parse(
            typeof raw === 'string' ? raw : raw.toString('utf-8')
          );
          if (data.type === 'execute') {
            resolve(data.payload.script);
          }
        });
      });

      // Start execution
      const resultPromise = server.executeAsync({
        scriptContent: 'print("hello")',
      });

      // Verify the server sent the execute message with correct script
      const receivedScript = await executePromise;
      expect(receivedScript).toBe('print("hello")');

      // Simulate plugin sending scriptComplete
      client!.send(
        JSON.stringify({
          type: 'scriptComplete',
          payload: { success: true },
        })
      );

      const result = await resultPromise;
      expect(result.success).toBe(true);
      expect(result.logs).toBe('');
    });

    it('collects output messages into logs', async () => {
      const ready = await createReadyServer();
      server = ready.server;
      client = ready.client;

      const resultPromise = server.executeAsync({
        scriptContent: 'print("test")',
      });

      // Wait for execute message to arrive
      await new Promise<void>((resolve) => {
        client!.on('message', (raw) => {
          const data = JSON.parse(
            typeof raw === 'string' ? raw : raw.toString('utf-8')
          );
          if (data.type === 'execute') resolve();
        });
      });

      // Send output messages
      client!.send(
        JSON.stringify({
          type: 'output',
          payload: {
            messages: [
              { level: 'Print', body: 'Line 1' },
              { level: 'Warning', body: 'Line 2' },
            ],
          },
        })
      );

      client!.send(
        JSON.stringify({
          type: 'output',
          payload: {
            messages: [{ level: 'Error', body: 'Line 3' }],
          },
        })
      );

      // Complete
      client!.send(
        JSON.stringify({
          type: 'scriptComplete',
          payload: { success: true },
        })
      );

      const result = await resultPromise;
      expect(result.success).toBe(true);
      expect(result.logs).toContain('Line 1');
      expect(result.logs).toContain('Line 2');
      expect(result.logs).toContain('Line 3');
    });

    it('calls onOutput for each output entry', async () => {
      const ready = await createReadyServer();
      server = ready.server;
      client = ready.client;

      const outputEntries: Array<{ level: string; body: string }> = [];

      const resultPromise = server.executeAsync({
        scriptContent: 'print("test")',
        onOutput: (level, body) => {
          outputEntries.push({ level, body });
        },
      });

      await new Promise<void>((resolve) => {
        client!.on('message', (raw) => {
          const data = JSON.parse(
            typeof raw === 'string' ? raw : raw.toString('utf-8')
          );
          if (data.type === 'execute') resolve();
        });
      });

      client!.send(
        JSON.stringify({
          type: 'output',
          payload: {
            messages: [
              { level: 'Print', body: 'hello' },
              { level: 'Error', body: 'oops' },
            ],
          },
        })
      );

      client!.send(
        JSON.stringify({
          type: 'scriptComplete',
          payload: { success: true },
        })
      );

      await resultPromise;

      expect(outputEntries).toEqual([
        { level: 'Print', body: 'hello' },
        { level: 'Error', body: 'oops' },
      ]);
    });

    it('returns failure with error message on script error', async () => {
      const ready = await createReadyServer();
      server = ready.server;
      client = ready.client;

      const resultPromise = server.executeAsync({
        scriptContent: 'error("boom")',
      });

      await new Promise<void>((resolve) => {
        client!.on('message', (raw) => {
          const data = JSON.parse(
            typeof raw === 'string' ? raw : raw.toString('utf-8')
          );
          if (data.type === 'execute') resolve();
        });
      });

      client!.send(
        JSON.stringify({
          type: 'scriptComplete',
          payload: { success: false, error: 'Script threw: boom' },
        })
      );

      const result = await resultPromise;
      expect(result.success).toBe(false);
      expect(result.logs).toContain('Script threw: boom');
    });

    it('returns failure when client disconnects during execution', async () => {
      const ready = await createReadyServer();
      server = ready.server;
      client = ready.client;

      const resultPromise = server.executeAsync({
        scriptContent: 'print("hi")',
      });

      await new Promise<void>((resolve) => {
        client!.on('message', (raw) => {
          const data = JSON.parse(
            typeof raw === 'string' ? raw : raw.toString('utf-8')
          );
          if (data.type === 'execute') resolve();
        });
      });

      // Close the client without sending scriptComplete
      client!.close();

      const result = await resultPromise;
      expect(result.success).toBe(false);
      expect(result.logs).toContain('Plugin disconnected before script completed');
    });

    it('times out when script takes too long', async () => {
      const ready = await createReadyServer();
      server = ready.server;
      client = ready.client;

      const resultPromise = server.executeAsync({
        scriptContent: 'while true do end',
        timeoutMs: 200,
      });

      // Don't send scriptComplete — let it time out

      const result = await resultPromise;
      expect(result.success).toBe(false);
      expect(result.logs).toContain('Timed out after 200ms');
    });
  });

  // -----------------------------------------------------------------------
  // Multi-execution (reuse)
  // -----------------------------------------------------------------------

  describe('multi-execution', () => {
    it('supports executing multiple scripts on the same session', async () => {
      const ready = await createReadyServer();
      server = ready.server;
      client = ready.client;

      // Helper: run one execute cycle
      const runOnce = async (script: string) => {
        const resultPromise = server!.executeAsync({ scriptContent: script });

        // Wait for execute message
        await new Promise<void>((resolve) => {
          const handler = (raw: any) => {
            const data = JSON.parse(
              typeof raw === 'string' ? raw : raw.toString('utf-8')
            );
            if (data.type === 'execute') {
              client!.off('message', handler);
              resolve();
            }
          };
          client!.on('message', handler);
        });

        // Respond with success
        client!.send(
          JSON.stringify({
            type: 'scriptComplete',
            payload: { success: true },
          })
        );

        return resultPromise;
      };

      const r1 = await runOnce('print("first")');
      expect(r1.success).toBe(true);

      const r2 = await runOnce('print("second")');
      expect(r2.success).toBe(true);

      const r3 = await runOnce('print("third")');
      expect(r3.success).toBe(true);
    });

    it('isolates logs between executions', async () => {
      const ready = await createReadyServer();
      server = ready.server;
      client = ready.client;

      const runWithOutput = async (outputBody: string) => {
        const resultPromise = server!.executeAsync({
          scriptContent: 'print("x")',
        });

        await new Promise<void>((resolve) => {
          const handler = (raw: any) => {
            const data = JSON.parse(
              typeof raw === 'string' ? raw : raw.toString('utf-8')
            );
            if (data.type === 'execute') {
              client!.off('message', handler);
              resolve();
            }
          };
          client!.on('message', handler);
        });

        client!.send(
          JSON.stringify({
            type: 'output',
            payload: { messages: [{ level: 'Print', body: outputBody }] },
          })
        );

        client!.send(
          JSON.stringify({
            type: 'scriptComplete',
            payload: { success: true },
          })
        );

        return resultPromise;
      };

      const r1 = await runWithOutput('output-from-first');
      const r2 = await runWithOutput('output-from-second');

      expect(r1.logs).toBe('output-from-first');
      expect(r1.logs).not.toContain('output-from-second');
      expect(r2.logs).toBe('output-from-second');
      expect(r2.logs).not.toContain('output-from-first');
    });
  });

  // -----------------------------------------------------------------------
  // Phase callbacks
  // -----------------------------------------------------------------------

  describe('onPhase', () => {
    it('fires phase callbacks in order during lifecycle', async () => {
      const phases: StudioBridgePhase[] = [];

      const ready = await createReadyServer({
        onPhase: (phase) => phases.push(phase),
      });
      server = ready.server;
      client = ready.client;

      // startAsync fires: launching, connecting
      // (no 'building' since we provided placePath)
      expect(phases).toContain('launching');
      expect(phases).toContain('connecting');

      // Execute
      const resultPromise = server.executeAsync({
        scriptContent: 'print("hi")',
      });

      await new Promise<void>((resolve) => {
        client!.on('message', (raw) => {
          const data = JSON.parse(
            typeof raw === 'string' ? raw : raw.toString('utf-8')
          );
          if (data.type === 'execute') resolve();
        });
      });

      expect(phases).toContain('executing');

      client!.send(
        JSON.stringify({
          type: 'scriptComplete',
          payload: { success: true },
        })
      );

      await resultPromise;
      expect(phases).toContain('done');

      // Verify order
      const idx = (p: StudioBridgePhase) => phases.indexOf(p);
      expect(idx('launching')).toBeLessThan(idx('connecting'));
      expect(idx('connecting')).toBeLessThan(idx('executing'));
      expect(idx('executing')).toBeLessThan(idx('done'));
    });
  });

  // -----------------------------------------------------------------------
  // Cleanup / stopAsync
  // -----------------------------------------------------------------------

  describe('stopAsync', () => {
    it('sends shutdown message to connected client', async () => {
      const ready = await createReadyServer();
      server = ready.server;
      client = ready.client;

      // Spy on the server-side socket's send method to verify the shutdown
      // message is sent (avoids race between send and terminate in cleanup).
      const connectedClient = (server as any)._connectedClient;
      const sendSpy = vi.spyOn(connectedClient, 'send');

      await server.stopAsync();

      expect(sendSpy).toHaveBeenCalledWith(
        JSON.stringify({ type: 'shutdown', payload: {} })
      );
    });

    it('can be called from idle state', async () => {
      server = new StudioBridgeServer({ placePath: '/fake/place.rbxl' });
      // Should not throw
      await server.stopAsync();
    });
  });
});
