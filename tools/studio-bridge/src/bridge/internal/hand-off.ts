/**
 * Failover detection and host takeover state machine. When the bridge host
 * process dies, surviving clients detect the disconnect and race to bind
 * the port, promoting themselves to become the new host.
 *
 * Two paths:
 * - Graceful: Host sends HostTransferNotice before shutting down. Clients
 *   skip jitter and attempt takeover immediately.
 * - Crash: No notification. Clients detect WebSocket disconnect, apply
 *   random jitter [0, 500ms] to avoid thundering herd, then race to bind.
 */

import { createServer, type Server } from 'net';
import { WebSocket } from 'ws';
import { HostUnreachableError } from '../types.js';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export type TakeoverState =
  | 'connected'
  | 'detecting-failure'
  | 'taking-over'
  | 'promoted'
  | 'fell-back-to-client';

export interface HandOffDependencies {
  tryBindAsync: (port: number) => Promise<boolean>;
  tryConnectAsClientAsync: (port: number) => Promise<boolean>;
  delay: (ms: number) => Promise<void>;
}

// ---------------------------------------------------------------------------
// Jitter
// ---------------------------------------------------------------------------

const MAX_CRASH_JITTER_MS = 500;
const MAX_RETRIES = 10;
const RETRY_DELAY_MS = 1_000;

/**
 * Compute jitter delay before takeover attempt. Graceful shutdowns skip
 * jitter entirely; crash-detected disconnects apply random [0, 500ms].
 */
export function computeTakeoverJitterMs(options: { graceful: boolean }): number {
  if (options.graceful) {
    return 0;
  }
  return Math.random() * MAX_CRASH_JITTER_MS;
}

// ---------------------------------------------------------------------------
// Default dependency implementations
// ---------------------------------------------------------------------------

/**
 * Attempt to bind a TCP server to the given port. Resolves true if the
 * bind succeeds (port is free), false if EADDRINUSE.
 */
function tryBindDefaultAsync(port: number): Promise<boolean> {
  return new Promise<boolean>((resolve) => {
    const server: Server = createServer();

    server.once('error', (err: NodeJS.ErrnoException) => {
      if (err.code === 'EADDRINUSE') {
        resolve(false);
      } else {
        resolve(false);
      }
    });

    server.once('listening', () => {
      server.close(() => {
        resolve(true);
      });
    });

    server.listen(port, 'localhost');
  });
}

/**
 * Attempt a WebSocket connection to ws://localhost:{port}/client with a
 * 2-second timeout. Resolves true if the connection succeeds (another
 * host is running), false otherwise.
 */
function tryConnectAsClientDefaultAsync(port: number): Promise<boolean> {
  const CONNECT_TIMEOUT_MS = 2_000;

  return new Promise<boolean>((resolve) => {
    const ws = new WebSocket(`ws://localhost:${port}/client`);

    const timer = setTimeout(() => {
      ws.removeAllListeners();
      ws.terminate();
      resolve(false);
    }, CONNECT_TIMEOUT_MS);

    ws.once('open', () => {
      clearTimeout(timer);
      ws.removeAllListeners();
      ws.close();
      resolve(true);
    });

    ws.once('error', () => {
      clearTimeout(timer);
      ws.removeAllListeners();
      resolve(false);
    });
  });
}

function delayDefault(ms: number): Promise<void> {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

// ---------------------------------------------------------------------------
// HandOffManager
// ---------------------------------------------------------------------------

export class HandOffManager {
  private _state: TakeoverState = 'connected';
  private _takeoverPending = false;
  private _port: number;
  private _deps: HandOffDependencies;

  constructor(options: { port: number; deps?: HandOffDependencies }) {
    this._port = options.port;
    this._deps = options.deps ?? {
      tryBindAsync: tryBindDefaultAsync,
      tryConnectAsClientAsync: tryConnectAsClientDefaultAsync,
      delay: delayDefault,
    };
  }

  /** Current state of the takeover state machine. */
  get state(): TakeoverState {
    return this._state;
  }

  /**
   * Called when the client receives a HostTransferNotice from the host.
   * Marks the pending transfer so the subsequent disconnect skips jitter.
   */
  onHostTransferNotice(): void {
    this._takeoverPending = true;
    this._state = 'detecting-failure';
  }

  /**
   * Called when the client detects that the host WebSocket has disconnected.
   * Runs the takeover state machine:
   *
   * 1. Apply jitter (0 for graceful, random [0, 500ms] for crash)
   * 2. Set state to 'taking-over'
   * 3. Retry loop (max 10 attempts):
   *    - Try to bind the port
   *    - If bind succeeds: state='promoted', return 'promoted'
   *    - If bind fails (EADDRINUSE): try connecting as client
   *      - If client connects: state='fell-back-to-client', return
   *      - If client fails: wait 1s and retry
   * 4. After 10 retries: throw HostUnreachableError
   */
  async onHostDisconnectedAsync(): Promise<'promoted' | 'fell-back-to-client'> {
    const graceful = this._takeoverPending;

    // Step 1: Jitter
    const jitterMs = computeTakeoverJitterMs({ graceful });
    if (jitterMs > 0) {
      await this._deps.delay(jitterMs);
    }

    // Step 2: Transition to taking-over
    this._state = 'taking-over';

    // Step 3: Retry loop
    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      const bindSuccess = await this._deps.tryBindAsync(this._port);

      if (bindSuccess) {
        this._state = 'promoted';
        return 'promoted';
      }

      // Port is in use — check if another host is running
      const clientConnected = await this._deps.tryConnectAsClientAsync(this._port);

      if (clientConnected) {
        this._state = 'fell-back-to-client';
        return 'fell-back-to-client';
      }

      // Neither bind nor connect worked — wait and retry
      if (attempt < MAX_RETRIES - 1) {
        await this._deps.delay(RETRY_DELAY_MS);
      }
    }

    // Step 4: Exhausted retries
    throw new HostUnreachableError('localhost', this._port);
  }
}
