/**
 * WebSocket smoke test — validates the entire server-side protocol by
 * simulating the plugin with a Node.js WebSocket client. No Studio needed.
 */

import { describe, it, expect } from 'vitest';
import { WebSocketServer, WebSocket } from 'ws';
import {
  encodeMessage,
  decodePluginMessage,
  type ServerMessage,
} from './web-socket-protocol.js';

/**
 * Helper: start a minimal WebSocket server that behaves like StudioBridge's
 * internal server, returning the port and a promise for the result.
 */
function createTestServer(expectedSessionId: string) {
  const wss = new WebSocketServer({ port: 0, path: `/${expectedSessionId}` });
  const logLines: string[] = [];

  const resultPromise = new Promise<{ success: boolean; logs: string }>(
    (resolve) => {
      wss.on('connection', (ws) => {
        ws.on('message', (raw) => {
          const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
          const msg = decodePluginMessage(data);
          if (!msg) return;

          if (msg.sessionId !== expectedSessionId) return;

          switch (msg.type) {
            case 'hello':
              if (msg.payload.sessionId === expectedSessionId) {
                ws.send(
                  encodeMessage({
                    type: 'welcome',
                    sessionId: expectedSessionId,
                    payload: { sessionId: expectedSessionId },
                  })
                );
              }
              break;
            case 'output':
              for (const entry of msg.payload.messages) {
                logLines.push(entry.body);
              }
              break;
            case 'scriptComplete':
              resolve({
                success: msg.payload.success,
                logs: logLines.join('\n'),
              });
              break;
          }
        });
      });
    }
  );

  const port = new Promise<number>((resolve) => {
    wss.on('listening', () => {
      const addr = wss.address();
      if (typeof addr === 'object' && addr !== null) {
        resolve(addr.port);
      }
    });
  });

  return { wss, port, resultPromise };
}

describe('WebSocket protocol smoke test', () => {
  it('completes full handshake → output → scriptComplete lifecycle', async () => {
    const sessionId = 'test-session-123';
    const {
      wss,
      port: portPromise,
      resultPromise,
    } = createTestServer(sessionId);

    try {
      const port = await portPromise;

      // Simulate the plugin side with a plain WebSocket client
      const ws = new WebSocket(`ws://localhost:${port}/${sessionId}`);

      await new Promise<void>((resolve, reject) => {
        ws.on('open', resolve);
        ws.on('error', reject);
      });

      // 1. Send hello
      ws.send(JSON.stringify({ type: 'hello', sessionId, payload: { sessionId } }));

      // 2. Wait for welcome
      const welcome = await new Promise<ServerMessage>((resolve) => {
        ws.on('message', (raw) => {
          const data = JSON.parse(
            typeof raw === 'string' ? raw : raw.toString('utf-8')
          );
          if (data.type === 'welcome') {
            resolve(data);
          }
        });
      });

      expect(welcome.type).toBe('welcome');
      expect(welcome.sessionId).toBe(sessionId);
      expect(
        (welcome as { payload: { sessionId: string } }).payload.sessionId
      ).toBe(sessionId);

      // 3. Send some output
      ws.send(
        JSON.stringify({
          type: 'output',
          sessionId,
          payload: {
            messages: [
              { level: 'Print', body: 'Hello from test' },
              { level: 'Warning', body: 'Test warning' },
            ],
          },
        })
      );

      // 4. Send scriptComplete
      ws.send(
        JSON.stringify({
          type: 'scriptComplete',
          sessionId,
          payload: { success: true },
        })
      );

      // 5. Verify result
      const result = await resultPromise;
      expect(result.success).toBe(true);
      expect(result.logs).toContain('Hello from test');
      expect(result.logs).toContain('Test warning');

      ws.close();
    } finally {
      wss.close();
    }
  });

  it('handles failed script execution', async () => {
    const sessionId = 'fail-session';
    const {
      wss,
      port: portPromise,
      resultPromise,
    } = createTestServer(sessionId);

    try {
      const port = await portPromise;
      const ws = new WebSocket(`ws://localhost:${port}/${sessionId}`);

      await new Promise<void>((resolve, reject) => {
        ws.on('open', resolve);
        ws.on('error', reject);
      });

      ws.send(JSON.stringify({ type: 'hello', sessionId, payload: { sessionId } }));

      // Wait for welcome before sending more
      await new Promise<void>((resolve) => {
        ws.on('message', (raw) => {
          const data = JSON.parse(
            typeof raw === 'string' ? raw : raw.toString('utf-8')
          );
          if (data.type === 'welcome') resolve();
        });
      });

      ws.send(
        JSON.stringify({
          type: 'output',
          sessionId,
          payload: {
            messages: [{ level: 'Error', body: 'Something went wrong' }],
          },
        })
      );

      ws.send(
        JSON.stringify({
          type: 'scriptComplete',
          sessionId,
          payload: { success: false, error: 'Script threw an error' },
        })
      );

      const result = await resultPromise;
      expect(result.success).toBe(false);
      expect(result.logs).toContain('Something went wrong');

      ws.close();
    } finally {
      wss.close();
    }
  });

  it('rejects hello with wrong session ID', async () => {
    const sessionId = 'correct-session';
    const wss = new WebSocketServer({ port: 0, path: `/${sessionId}` });

    try {
      const port = await new Promise<number>((resolve) => {
        wss.on('listening', () => {
          const addr = wss.address();
          if (typeof addr === 'object' && addr !== null) resolve(addr.port);
        });
      });

      let welcomeSent = false;
      wss.on('connection', (ws) => {
        ws.on('message', (raw) => {
          const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
          const msg = decodePluginMessage(data);
          if (msg?.type === 'hello' && msg.sessionId === sessionId && msg.payload.sessionId === sessionId) {
            welcomeSent = true;
            ws.send(encodeMessage({ type: 'welcome', sessionId, payload: { sessionId } }));
          }
        });
      });

      const ws = new WebSocket(`ws://localhost:${port}/${sessionId}`);
      await new Promise<void>((resolve, reject) => {
        ws.on('open', resolve);
        ws.on('error', reject);
      });

      // Send hello with wrong session ID
      ws.send(
        JSON.stringify({
          type: 'hello',
          sessionId: 'wrong-session',
          payload: { sessionId: 'wrong-session' },
        })
      );

      // Give the server time to process
      await new Promise((resolve) => setTimeout(resolve, 100));

      expect(welcomeSent).toBe(false);

      ws.close();
    } finally {
      wss.close();
    }
  });
});
