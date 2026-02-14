/**
 * Manual validation helper — starts the WebSocket server and injects the
 * plugin, but does NOT launch Studio automatically. Open Studio manually
 * with any place file to observe the plugin connect.
 *
 * Usage: npx tsx test/manual/ws-server-only.ts
 */

import { WebSocketServer } from 'ws';
import {
  encodeMessage,
  decodePluginMessage,
} from '../../src/protocol.js';
import { injectPluginAsync } from '../../src/plugin-injector.js';
import { randomUUID } from 'crypto';

const sessionId = randomUUID();

async function main() {
  const wss = new WebSocketServer({ port: 0 });

  const port = await new Promise<number>((resolve) => {
    wss.on('listening', () => {
      const addr = wss.address();
      if (typeof addr === 'object' && addr !== null) {
        resolve(addr.port);
      }
    });
  });

  console.log(`[ws-server] Listening on port ${port}`);
  console.log(`[ws-server] Session ID: ${sessionId}`);

  // Inject plugin
  const plugin = await injectPluginAsync({
    port,
    sessionId,
    scriptContent: 'print("[studio-bridge] Hello from manual test!")\nprint("[studio-bridge] Script executed successfully")',
  });

  console.log(`[ws-server] Plugin injected: ${plugin.pluginPath}`);
  console.log(`[ws-server] Open Roblox Studio (any place file) to test the connection.`);
  console.log(`[ws-server] Press Ctrl+C to stop.\n`);

  wss.on('connection', (ws) => {
    console.log('[ws-server] Client connected!');

    ws.on('message', (raw) => {
      const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
      console.log(`[ws-server] Received: ${data}`);

      const msg = decodePluginMessage(data);
      if (!msg) {
        console.log('[ws-server] Could not decode message');
        return;
      }

      switch (msg.type) {
        case 'hello':
          console.log(`[ws-server] Got hello (sessionId: ${msg.payload.sessionId})`);
          if (msg.payload.sessionId === sessionId) {
            console.log('[ws-server] Session ID matches! Sending welcome...');
            ws.send(encodeMessage({ type: 'welcome', payload: { sessionId } }));
          } else {
            console.log(`[ws-server] Wrong session ID (expected: ${sessionId})`);
          }
          break;

        case 'output':
          for (const entry of msg.payload.messages) {
            console.log(`[ws-server] [${entry.level}] ${entry.body}`);
          }
          break;

        case 'scriptComplete':
          console.log(`[ws-server] Script complete! success=${msg.payload.success}`);
          if (msg.payload.error) {
            console.log(`[ws-server] Error: ${msg.payload.error}`);
          }

          // Send shutdown
          console.log('[ws-server] Sending shutdown...');
          ws.send(encodeMessage({ type: 'shutdown', payload: {} }));

          // Clean up after a short delay
          setTimeout(async () => {
            console.log('[ws-server] Cleaning up...');
            await plugin.cleanupAsync();
            wss.close();
            console.log('[ws-server] Done!');
            process.exit(0);
          }, 1000);
          break;
      }
    });

    ws.on('close', () => {
      console.log('[ws-server] Client disconnected');
    });
  });

  // Cleanup on Ctrl+C
  process.on('SIGINT', async () => {
    console.log('\n[ws-server] Interrupted, cleaning up...');
    await plugin.cleanupAsync();
    wss.close();
    process.exit(0);
  });
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
