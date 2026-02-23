/**
 * Integration tests for crash-recovery failover. Verifies that when a host
 * process dies without sending a HostTransferNotice, clients detect the
 * disconnect, apply random jitter, and race to bind the port.
 *
 * Uses real BridgeHost and HandOffManager instances with ephemeral ports.
 */

import { describe, it, expect, afterEach, vi } from 'vitest';
import { WebSocket } from 'ws';
import { BridgeHost } from '../bridge-host.js';
import { HandOffManager, computeTakeoverJitterMs } from '../hand-off.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function connectClientWsAsync(port: number): Promise<WebSocket> {
  return new Promise<WebSocket>((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}/client`);
    ws.on('open', () => resolve(ws));
    ws.on('error', reject);
  });
}

function waitForClose(ws: WebSocket, timeoutMs = 5_000): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    if (ws.readyState === WebSocket.CLOSED) {
      resolve();
      return;
    }
    const timer = setTimeout(() => {
      reject(new Error('Timed out waiting for WebSocket close'));
    }, timeoutMs);
    ws.on('close', () => {
      clearTimeout(timer);
      resolve();
    });
  });
}

function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('Crash recovery failover', () => {
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

  it('client detects crash and takes over after jitter', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    clientWs = await connectClientWsAsync(port);

    // Force-close the host (simulates crash — no HostTransferNotice sent)
    await host.stopAsync();
    host = undefined;

    // Wait for the client WebSocket to detect the close
    await waitForClose(clientWs);

    // Client did NOT receive a transfer notice, so this is a crash path
    const handOff = new HandOffManager({ port });
    // Do NOT call onHostTransferNotice — this is a crash

    const outcome = await handOff.onHostDisconnectedAsync();
    expect(outcome).toBe('promoted');
    expect(handOff.state).toBe('promoted');
  });

  it('crash jitter is in [0, 500ms] range', () => {
    // Verify the jitter function produces values in the correct range
    for (let i = 0; i < 200; i++) {
      const jitter = computeTakeoverJitterMs({ graceful: false });
      expect(jitter).toBeGreaterThanOrEqual(0);
      expect(jitter).toBeLessThanOrEqual(500);
    }
  });

  it('crash jitter is zero for graceful shutdowns', () => {
    const jitter = computeTakeoverJitterMs({ graceful: true });
    expect(jitter).toBe(0);
  });

  it('multiple clients after crash: exactly one wins the port bind race', async () => {
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    // Connect two clients
    const ws1 = await connectClientWsAsync(port);
    const ws2 = await connectClientWsAsync(port);

    // Force-close the host (crash)
    await host.stopAsync();
    host = undefined;

    // Wait for both clients to detect the close
    await Promise.all([
      waitForClose(ws1),
      waitForClose(ws2),
    ]);

    // Both clients attempt takeover without transfer notice (crash path).
    // We need to coordinate: the first one to bind starts a new host so the
    // second can fall back.
    const handOff1 = new HandOffManager({ port });
    const handOff2 = new HandOffManager({ port });

    // Zero-jitter for determinism: mock Math.random to return 0
    const randomSpy = vi.spyOn(Math, 'random').mockReturnValue(0);

    const results = await Promise.allSettled([
      (async () => {
        const result = await handOff1.onHostDisconnectedAsync();
        if (result === 'promoted') {
          // Bind the port so the other client can fall back
          newHost = new BridgeHost();
          await newHost.startAsync({ port });
        }
        return result;
      })(),
      (async () => {
        // Small delay so the first client binds first
        await delay(100);
        return handOff2.onHostDisconnectedAsync();
      })(),
    ]);

    randomSpy.mockRestore();

    const fulfilled = results
      .filter((r): r is PromiseFulfilledResult<'promoted' | 'fell-back-to-client'> => r.status === 'fulfilled')
      .map((r) => r.value);

    // At least one should be promoted
    expect(fulfilled.filter((o) => o === 'promoted')).toHaveLength(1);

    // Clean up
    ws1.terminate();
    ws2.terminate();
    clientWs = undefined;
  });

  it('takeover succeeds even when host port is briefly in TIME_WAIT', async () => {
    // This test verifies that after a host stops, the port becomes available
    // quickly enough for takeover. Node's SO_REUSEADDR helps here.
    host = new BridgeHost();
    const port = await host.startAsync({ port: 0 });

    await host.stopAsync();
    host = undefined;

    // Immediately try to bind
    const handOff = new HandOffManager({ port });
    handOff.onHostTransferNotice(); // skip jitter

    const outcome = await handOff.onHostDisconnectedAsync();
    expect(outcome).toBe('promoted');

    // Verify the port is actually usable
    newHost = new BridgeHost();
    const newPort = await newHost.startAsync({ port });
    expect(newPort).toBe(port);
  });
});
