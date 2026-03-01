/**
 * HTTP health check endpoint for the bridge host. The handler is registered
 * on the TransportServer for the '/health' path. A standalone client function
 * (`checkHealthAsync`) allows probing a running bridge host.
 */

import http from 'http';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export interface HealthResponse {
  status: 'ok';
  port: number;
  protocolVersion: number;
  sessions: number;
  uptime: number;
  hostUptime: number;
  lastFailoverAt: string | null;
}

export interface HealthInfo {
  port: number;
  protocolVersion: number;
  sessions: number;
  startTime: number;
  hostStartTime?: number;
  lastFailoverAt?: string | null;
}

// ---------------------------------------------------------------------------
// Health check client
// ---------------------------------------------------------------------------

const HEALTH_TIMEOUT_MS = 2_000;

/**
 * Check the health endpoint of a running bridge host.
 * Returns the parsed HealthResponse, or null if the health check fails.
 */
export async function checkHealthAsync(
  port: number,
  host?: string,
): Promise<HealthResponse | null> {
  const targetHost = host ?? 'localhost';
  const url = `http://${targetHost}:${port}/health`;

  return new Promise<HealthResponse | null>((resolve) => {
    const req = http.get(url, { timeout: HEALTH_TIMEOUT_MS }, (res) => {
      let body = '';
      res.on('data', (chunk: Buffer | string) => {
        body += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body) as HealthResponse;
          if (parsed.status === 'ok' && typeof parsed.port === 'number') {
            resolve(parsed);
          } else {
            resolve(null);
          }
        } catch {
          resolve(null);
        }
      });
      res.on('error', () => {
        resolve(null);
      });
    });

    req.on('error', () => {
      resolve(null);
    });

    req.on('timeout', () => {
      req.destroy();
      resolve(null);
    });
  });
}

// ---------------------------------------------------------------------------
// Health handler (used by BridgeHost to register on TransportServer)
// ---------------------------------------------------------------------------

/**
 * Create an HTTP request handler that returns the health JSON.
 * The `getInfo` callback is invoked on each request to gather fresh data.
 */
export function createHealthHandler(
  getInfo: () => HealthInfo,
): (req: http.IncomingMessage, res: http.ServerResponse) => void {
  return (_req, res) => {
    const info = getInfo();
    const now = Date.now();
    const hostStartTime = info.hostStartTime ?? info.startTime;
    const response: HealthResponse = {
      status: 'ok',
      port: info.port,
      protocolVersion: info.protocolVersion,
      sessions: info.sessions,
      uptime: now - info.startTime,
      hostUptime: now - hostStartTime,
      lastFailoverAt: info.lastFailoverAt ?? null,
    };

    const body = JSON.stringify(response);
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
    });
    res.end(body);
  };
}
