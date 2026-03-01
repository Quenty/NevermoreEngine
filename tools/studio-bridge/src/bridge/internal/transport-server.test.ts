/**
 * Unit tests for TransportServer — validates port binding, path-based
 * WebSocket routing, HTTP health endpoint delegation, and cleanup.
 */

import { describe, it, expect, afterEach } from 'vitest';
import { WebSocket } from 'ws';
import http from 'http';
import { TransportServer } from './transport-server.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function connectWs(port: number, path: string): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}${path}`);
    ws.on('open', () => resolve(ws));
    ws.on('error', reject);
  });
}

function connectWsExpectReject(port: number, path: string): Promise<string> {
  return new Promise((resolve) => {
    const ws = new WebSocket(`ws://localhost:${port}${path}`);
    ws.on('error', () => resolve('error'));
    ws.on('unexpected-response', () => {
      ws.close();
      resolve('rejected');
    });
  });
}

function httpGet(port: number, path: string): Promise<{ status: number; body: string }> {
  return new Promise((resolve, reject) => {
    http.get(`http://localhost:${port}${path}`, (res) => {
      let body = '';
      res.on('data', (chunk: Buffer | string) => { body += chunk; });
      res.on('end', () => {
        resolve({ status: res.statusCode ?? 0, body });
      });
      res.on('error', reject);
    }).on('error', reject);
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('TransportServer', () => {
  let server: TransportServer | undefined;
  const openClients: WebSocket[] = [];

  afterEach(async () => {
    for (const ws of openClients) {
      if (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING) {
        ws.close();
      }
    }
    openClients.length = 0;

    if (server) {
      await server.stopAsync();
      server = undefined;
    }
  });

  // -----------------------------------------------------------------------
  // Startup and port binding
  // -----------------------------------------------------------------------

  describe('startAsync', () => {
    it('binds to an ephemeral port and returns the actual port', async () => {
      server = new TransportServer();
      const port = await server.startAsync({ port: 0 });

      expect(port).toBeGreaterThan(0);
      expect(server.port).toBe(port);
      expect(server.isListening).toBe(true);
    });

    it('throws when trying to start while already listening', async () => {
      server = new TransportServer();
      await server.startAsync({ port: 0 });

      await expect(server.startAsync({ port: 0 })).rejects.toThrow(
        'TransportServer is already listening',
      );
    });

    it('reports EADDRINUSE when port is taken', async () => {
      server = new TransportServer();
      const port = await server.startAsync({ port: 0 });

      const server2 = new TransportServer();
      await expect(server2.startAsync({ port })).rejects.toThrow(
        `Port ${port} is already in use`,
      );
    });
  });

  // -----------------------------------------------------------------------
  // WebSocket path-based routing
  // -----------------------------------------------------------------------

  describe('onConnection', () => {
    it('routes WebSocket connections to registered path handlers', async () => {
      server = new TransportServer();

      const connections: string[] = [];
      server.onConnection('/plugin', () => { connections.push('plugin'); });
      server.onConnection('/client', () => { connections.push('client'); });

      const port = await server.startAsync({ port: 0 });

      const ws1 = await connectWs(port, '/plugin');
      openClients.push(ws1);
      // Allow event loop to process
      await new Promise((r) => setTimeout(r, 50));
      expect(connections).toContain('plugin');

      const ws2 = await connectWs(port, '/client');
      openClients.push(ws2);
      await new Promise((r) => setTimeout(r, 50));
      expect(connections).toContain('client');
    });

    it('rejects WebSocket connections on unregistered paths with 404', async () => {
      server = new TransportServer();
      server.onConnection('/plugin', () => {});
      const port = await server.startAsync({ port: 0 });

      const result = await connectWsExpectReject(port, '/unknown');
      expect(['error', 'rejected']).toContain(result);
    });

    it('passes the WebSocket and request to the handler', async () => {
      server = new TransportServer();

      let receivedWs: WebSocket | undefined;
      let receivedUrl: string | undefined;

      server.onConnection('/plugin', (ws, req) => {
        receivedWs = ws;
        receivedUrl = req.url;
      });

      const port = await server.startAsync({ port: 0 });
      const ws = await connectWs(port, '/plugin');
      openClients.push(ws);

      await new Promise((r) => setTimeout(r, 50));

      expect(receivedWs).toBeDefined();
      expect(receivedUrl).toBe('/plugin');
    });
  });

  // -----------------------------------------------------------------------
  // HTTP request handling
  // -----------------------------------------------------------------------

  describe('onHttpRequest', () => {
    it('routes HTTP GET requests to registered path handlers', async () => {
      server = new TransportServer();
      server.onHttpRequest('/health', (_req, res) => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok' }));
      });

      const port = await server.startAsync({ port: 0 });
      const result = await httpGet(port, '/health');

      expect(result.status).toBe(200);
      expect(JSON.parse(result.body)).toEqual({ status: 'ok' });
    });

    it('returns 404 for unregistered HTTP paths', async () => {
      server = new TransportServer();
      const port = await server.startAsync({ port: 0 });

      const result = await httpGet(port, '/nonexistent');
      expect(result.status).toBe(404);
    });
  });

  // -----------------------------------------------------------------------
  // stopAsync
  // -----------------------------------------------------------------------

  describe('stopAsync', () => {
    it('closes the server and resets state', async () => {
      server = new TransportServer();
      await server.startAsync({ port: 0 });

      expect(server.isListening).toBe(true);

      await server.stopAsync();

      expect(server.isListening).toBe(false);
      expect(server.port).toBe(0);
    });

    it('is idempotent', async () => {
      server = new TransportServer();
      await server.startAsync({ port: 0 });

      await server.stopAsync();
      // Second call should not throw
      await server.stopAsync();
    });

    it('terminates connected WebSocket clients', async () => {
      server = new TransportServer();
      server.onConnection('/plugin', () => {});
      const port = await server.startAsync({ port: 0 });

      const ws = await connectWs(port, '/plugin');

      const closedPromise = new Promise<void>((resolve) => {
        ws.on('close', () => resolve());
      });

      await server.stopAsync();
      await closedPromise;
      // If we get here, the client was terminated
    });
  });
});
