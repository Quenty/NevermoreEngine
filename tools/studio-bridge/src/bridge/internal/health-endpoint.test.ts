/**
 * Unit tests for the health endpoint — validates the HTTP health handler
 * and the checkHealthAsync client function.
 */

import { describe, it, expect, afterEach } from 'vitest';
import http from 'http';
import { checkHealthAsync, createHealthHandler, type HealthInfo } from './health-endpoint.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Start a tiny HTTP server that serves the health handler on /health.
 * Returns the port and a cleanup function.
 */
async function startHealthServerAsync(
  getInfo: () => HealthInfo,
): Promise<{ port: number; closeAsync: () => Promise<void> }> {
  const handler = createHealthHandler(getInfo);
  const server = http.createServer((req, res) => {
    if (req.url === '/health') {
      handler(req, res);
    } else {
      res.writeHead(404);
      res.end();
    }
  });

  return new Promise((resolve) => {
    server.listen(0, 'localhost', () => {
      const addr = server.address();
      const port = typeof addr === 'object' && addr !== null ? addr.port : 0;
      resolve({
        port,
        closeAsync: () => new Promise<void>((r) => server.close(() => r())),
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('health-endpoint', () => {
  let closeServer: (() => Promise<void>) | undefined;

  afterEach(async () => {
    if (closeServer) {
      await closeServer();
      closeServer = undefined;
    }
  });

  describe('createHealthHandler', () => {
    it('returns a JSON response with status ok', async () => {
      const startTime = Date.now() - 5000;
      const { port, closeAsync } = await startHealthServerAsync(() => ({
        port: 38741,
        protocolVersion: 2,
        sessions: 3,
        startTime,
      }));
      closeServer = closeAsync;

      const result = await checkHealthAsync(port);

      expect(result).not.toBeNull();
      expect(result!.status).toBe('ok');
      expect(result!.port).toBe(38741);
      expect(result!.protocolVersion).toBe(2);
      expect(result!.sessions).toBe(3);
      expect(result!.uptime).toBeGreaterThanOrEqual(4000);
    });

    it('returns fresh data on each request', async () => {
      let sessionCount = 0;
      const { port, closeAsync } = await startHealthServerAsync(() => ({
        port: 38741,
        protocolVersion: 2,
        sessions: ++sessionCount,
        startTime: Date.now(),
      }));
      closeServer = closeAsync;

      const r1 = await checkHealthAsync(port);
      const r2 = await checkHealthAsync(port);

      expect(r1!.sessions).toBe(1);
      expect(r2!.sessions).toBe(2);
    });
  });

  describe('checkHealthAsync', () => {
    it('returns null when no server is running on the port', async () => {
      // Use a port that's almost certainly not in use
      const result = await checkHealthAsync(19999);
      expect(result).toBeNull();
    });

    it('returns null when server returns invalid JSON', async () => {
      const server = http.createServer((_req, res) => {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('not json');
      });

      const port = await new Promise<number>((resolve) => {
        server.listen(0, 'localhost', () => {
          const addr = server.address();
          resolve(typeof addr === 'object' && addr !== null ? addr.port : 0);
        });
      });
      closeServer = () => new Promise<void>((r) => server.close(() => r()));

      const result = await checkHealthAsync(port);
      expect(result).toBeNull();
    });

    it('returns null when server returns JSON without status field', async () => {
      const server = http.createServer((_req, res) => {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ notStatus: true }));
      });

      const port = await new Promise<number>((resolve) => {
        server.listen(0, 'localhost', () => {
          const addr = server.address();
          resolve(typeof addr === 'object' && addr !== null ? addr.port : 0);
        });
      });
      closeServer = () => new Promise<void>((r) => server.close(() => r()));

      const result = await checkHealthAsync(port);
      expect(result).toBeNull();
    });

    it('returns valid health response from a running host', async () => {
      const { port, closeAsync } = await startHealthServerAsync(() => ({
        port: 38741,
        protocolVersion: 2,
        sessions: 1,
        startTime: Date.now() - 1000,
      }));
      closeServer = closeAsync;

      const result = await checkHealthAsync(port);

      expect(result).not.toBeNull();
      expect(result!.status).toBe('ok');
      expect(typeof result!.uptime).toBe('number');
    });
  });
});
