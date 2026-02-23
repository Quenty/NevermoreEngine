/**
 * Role detection utility for the bridge network. Determines whether the
 * current process should act as a bridge host or bridge client by attempting
 * to bind the port and probing the health endpoint.
 *
 * Algorithm:
 * 1. If `remoteHost` specified -> client
 * 2. Try to bind port -> host
 * 3. EADDRINUSE -> check health endpoint
 *    a. Health succeeds -> client (host is alive)
 *    b. Health fails -> wait, retry bind (stale host)
 */

import { existsSync } from 'node:fs';
import { TransportServer } from './transport-server.js';
import { checkHealthAsync } from './health-endpoint.js';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export type DetectedRole = 'host' | 'client';

export interface DetectRoleResult {
  role: DetectedRole;
  server?: TransportServer;
  port: number;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const STALE_RETRY_DELAY_MS = 1_000;
const MAX_STALE_RETRIES = 3;
const DEFAULT_BRIDGE_PORT = 38741;

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

/**
 * Detect whether this process should act as a bridge host or client.
 *
 * - If `remoteHost` is specified, always returns 'client'.
 * - Otherwise, tries to bind the port. Success means 'host'.
 * - If EADDRINUSE, probes the health endpoint:
 *   - If healthy, returns 'client'.
 *   - If unhealthy (stale port), waits and retries the bind.
 */
export async function detectRoleAsync(options: {
  port: number;
  remoteHost?: string;
}): Promise<DetectRoleResult> {
  // If remoteHost is specified, always connect as client
  if (options.remoteHost) {
    return { role: 'client', port: options.port };
  }

  // Try to bind the port, with retries for stale ports
  for (let attempt = 0; attempt <= MAX_STALE_RETRIES; attempt++) {
    const server = new TransportServer();

    try {
      const boundPort = await server.startAsync({ port: options.port });
      // We successfully bound -- we are the host.
      // Stop the server for now; the caller (BridgeConnection) will
      // use this server instance to set up BridgeHost.
      // Actually, we return the server still listening so the caller
      // can reuse it. But BridgeHost creates its own TransportServer.
      // So we stop it and let the caller know to create a BridgeHost.
      await server.stopAsync();
      return { role: 'host', port: boundPort };
    } catch (err: unknown) {
      const isAddressInUse =
        err instanceof Error &&
        (err.message.includes('already in use') ||
          (err as NodeJS.ErrnoException).code === 'EADDRINUSE');

      if (!isAddressInUse) {
        throw err;
      }

      // Port is in use -- check if a healthy bridge host is there
      const health = await checkHealthAsync(options.port);

      if (health) {
        // A live bridge host is running; become a client
        return { role: 'client', port: options.port };
      }

      // Health check failed -- stale port. Wait and retry.
      if (attempt < MAX_STALE_RETRIES) {
        await new Promise((resolve) => setTimeout(resolve, STALE_RETRY_DELAY_MS));
      }
    }
  }

  // All retries exhausted
  throw new Error(
    `Port ${options.port} is held by another process and no bridge host responded on /health. ` +
    `The port may be in use by a non-bridge process.`,
  );
}

// ---------------------------------------------------------------------------
// Devcontainer detection
// ---------------------------------------------------------------------------

/**
 * Detect whether running inside a devcontainer.
 * Checks: REMOTE_CONTAINERS, CODESPACES, CONTAINER env vars, /.dockerenv file.
 * Wide net -- false positive = 3s delay then fallback. False negative = user uses --remote.
 */
export function isDevcontainer(): boolean {
  return !!(
    process.env.REMOTE_CONTAINERS ||
    process.env.CODESPACES ||
    process.env.CONTAINER ||
    existsSync('/.dockerenv')
  );
}

/**
 * Get default remote host for devcontainer environments.
 * Returns "localhost:38741" inside devcontainer, null otherwise.
 */
export function getDefaultRemoteHost(): string | null {
  if (isDevcontainer()) {
    return `localhost:${DEFAULT_BRIDGE_PORT}`;
  }
  return null;
}
