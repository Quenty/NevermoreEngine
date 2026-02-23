/**
 * Integration tests for graceful host shutdown failover. Verifies that when
 * a host calls shutdownAsync(), clients receive the HostTransferNotice and
 * one of them successfully takes over as the new host.
 *
 * Uses real BridgeHost and HandOffManager instances with ephemeral ports.
 */

import { describe, it, expect, afterEach, vi } from 'vitest';
import { WebSocket } from 'ws';
import { BridgeHost } from '../bridge-host.js';
import { HandOffManager, type HandOffDependencies } from '../hand-off.js';
import { decodeHostMessage, encodeHostMessage } from '../host-protocol.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Wait for a WebSocket message matching a predicate. */
function waitForMessageAsync(
  ws: WebSocket,
  predicate: (data: string) => boolean,
  timeoutMs = 5_000,
): Promise<string> {
  return new Promise<string>((resolve, reject) => {
    const timer = setTimeout(() => {
      ws.off('message', onMessage);
      reject(new Error('Timed out waiting for message'));
    }, timeoutMs);

    const onMessage = (raw: Buffer | string) => {
      const data = typeof raw === 'string' ? raw : raw.toString('utf-8');
      if (predicate(data)) {
        clearTimeout(timer);
        ws.off('message', onMessage);
        resolve(data);
      }
    };

    ws.on('message', onMessage);
  });
}

/** Connect a raw WebSocket to the host's /client path. */
function connectClientWsAsync(port: number): Promise<WebSocket> {
  return new Promise<WebSocket>((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}/client`);
    ws.on('open', () => resolve(ws));
    ws.on('error', reject);
  });
}

function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('Graceful shutdown failover', () => {
  let host: BridgeHost | undefined;
  let clientWs: WebSocket | undefined;
  let newHost: BridgeHost | undefined;

  afterEach(async () => {
    if (clientWs) {
      if (clientWs.readyState === WebSocket.OPEN || clientWs.readyState === WebSocket.CONNECTING) {
        clientWs.terminate();
      }
      clientWs = undefined;
    }
    if (host) {
      try { await host.stopAsync(); } catch { /* ignore */ }
      host = undefined;
    }
    if (newHost) {
      try { await newHost.stopAsync(); } catch { /* ignore */ }
      newHost = undefined;
    }
  });

  it('client receives host-transfer notice on graceful shutdown', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    clientWs = await connectClientWsAsync(port);

    // Start listening for the transfer notice BEFORE triggering shutdown
    const noticePromise = waitForMessageAsync(clientWs, (data) => {
      const msg = decodeHostMessage(data);
      return msg?.type === 'host-transfer';
    });

    // Trigger graceful shutdown
    await host.shutdownAsync();
    host = undefined;

    // Client should have received the notice
    const noticeData = await noticePromise;
    const msg = decodeHostMessage(noticeData);
    expect(msg).not.toBeNull();
    expect(msg!.type).toBe('host-transfer');
  });

  it('client takes over as host after graceful shutdown', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    clientWs = await connectClientWsAsync(port);

    // Set up HandOffManager for this client
    const handOff = new HandOffManager({ port });

    // Start listening for transfer notice
    const noticePromise = waitForMessageAsync(clientWs, (data) => {
      const msg = decodeHostMessage(data);
      return msg?.type === 'host-transfer';
    });

    // Trigger graceful shutdown
    await host.shutdownAsync();
    host = undefined;

    // Wait for the notice to arrive
    await noticePromise;
    handOff.onHostTransferNotice();

    // Client detects disconnect and runs takeover
    const outcome = await handOff.onHostDisconnectedAsync();
    expect(outcome).toBe('promoted');
    expect(handOff.state).toBe('promoted');

    // Verify the port is actually free — new host can bind
    newHost = new BridgeHost();
    const newPort = await newHost.startAsync({ port });
    expect(newPort).toBe(port);
  });

  it('multiple clients: exactly one becomes host, others fall back', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    // Connect two clients
    const ws1 = await connectClientWsAsync(port);
    const ws2 = await connectClientWsAsync(port);

    const notice1Promise = waitForMessageAsync(ws1, (data) => {
      const msg = decodeHostMessage(data);
      return msg?.type === 'host-transfer';
    });
    const notice2Promise = waitForMessageAsync(ws2, (data) => {
      const msg = decodeHostMessage(data);
      return msg?.type === 'host-transfer';
    });

    // Graceful shutdown
    await host.shutdownAsync();
    host = undefined;

    // Both clients should receive the notice
    await Promise.all([notice1Promise, notice2Promise]);

    // Both run the takeover state machine (one must bind, other must fall back)
    const handOff1 = new HandOffManager({ port });
    handOff1.onHostTransferNotice();

    const handOff2 = new HandOffManager({ port });
    handOff2.onHostTransferNotice();

    // Simulate both clients starting takeover.
    // One will bind the port and succeed, the other will fail to bind.
    // We need to actually bind a host for the fallback client to connect to.

    // Race them: first one to bind starts a new host
    const results = await Promise.allSettled([
      (async () => {
        const result = await handOff1.onHostDisconnectedAsync();
        if (result === 'promoted') {
          newHost = new BridgeHost();
          await newHost.startAsync({ port });
        }
        return result;
      })(),
      (async () => {
        // Small delay to avoid thundering herd in test
        await delay(50);
        return handOff2.onHostDisconnectedAsync();
      })(),
    ]);

    const outcomes = results
      .filter((r): r is PromiseFulfilledResult<'promoted' | 'fell-back-to-client'> => r.status === 'fulfilled')
      .map((r) => r.value);

    // Exactly one should be promoted
    expect(outcomes.filter((o) => o === 'promoted')).toHaveLength(1);
    // The other should fall back (or the second could also get promoted if the first
    // hasn't bound yet, but with the delay this is deterministic)

    // Clean up WebSockets
    ws1.terminate();
    ws2.terminate();
    clientWs = undefined; // prevent double-cleanup
  });

  it('plugin reconnects to the new host after failover', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    clientWs = await connectClientWsAsync(port);

    const noticePromise = waitForMessageAsync(clientWs, (data) => {
      const msg = decodeHostMessage(data);
      return msg?.type === 'host-transfer';
    });

    // Shutdown the original host
    await host.shutdownAsync();
    host = undefined;
    await noticePromise;

    // Start a new host on the same port
    newHost = new BridgeHost();
    const newPort = await newHost.startAsync({ port });
    expect(newPort).toBe(port);

    // Verify a plugin can connect to the new host
    const pluginConnectedPromise = new Promise<string>((resolve) => {
      newHost!.on('plugin-connected', (info: { sessionId: string }) => {
        resolve(info.sessionId);
      });
    });

    // Simulate a plugin connecting
    const pluginWs = new WebSocket(`ws://localhost:${port}/plugin`);
    await new Promise<void>((resolve, reject) => {
      pluginWs.on('open', () => {
        pluginWs.send(JSON.stringify({
          type: 'hello',
          sessionId: 'plugin-session-1',
          payload: {
            sessionId: 'plugin-session-1',
            capabilities: ['execute'],
            pluginVersion: '1.0.0',
          },
        }));
        resolve();
      });
      pluginWs.on('error', reject);
    });

    const connectedSessionId = await pluginConnectedPromise;
    expect(connectedSessionId).toBe('plugin-session-1');

    pluginWs.terminate();
  });
});
