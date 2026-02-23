/**
 * Handler for the `serve` command. Starts a dedicated bridge host process
 * that stays alive, accepting plugin and client connections.
 */

import { BridgeConnection } from '../bridge/index.js';
import type { BridgeSession } from '../bridge/index.js';

export interface ServeOptions {
  port?: number;
  json?: boolean;
  timeout?: number;
}

export interface ServeResult {
  port: number;
  event: string;
}

/**
 * Start a dedicated bridge host process.
 * Blocks until shutdown signal or timeout.
 */
export async function serveHandlerAsync(
  options: ServeOptions = {},
): Promise<ServeResult> {
  const port = options.port ?? 38741;

  let connection: BridgeConnection;
  try {
    connection = await BridgeConnection.connectAsync({
      port,
      keepAlive: true,
    });
  } catch (err: unknown) {
    if (
      err instanceof Error &&
      'code' in err &&
      (err as NodeJS.ErrnoException).code === 'EADDRINUSE'
    ) {
      throw new Error(
        `Port ${port} is already in use. A bridge host is already running. ` +
        `Connect as a client with any studio-bridge command, or use --port to start on a different port.`,
      );
    }
    throw err;
  }

  // Log startup
  if (options.json) {
    console.log(JSON.stringify({ event: 'started', port: connection.port, timestamp: new Date().toISOString() }));
  } else {
    console.log(`Bridge host listening on port ${connection.port}`);
  }

  // Set up event listeners for session changes
  connection.on('session-connected', (session: BridgeSession) => {
    if (options.json) {
      console.log(JSON.stringify({
        event: 'pluginConnected',
        sessionId: session.info.sessionId,
        context: session.info.context,
        timestamp: new Date().toISOString(),
      }));
    } else {
      console.log(`Plugin connected: ${session.info.sessionId} (${session.info.context})`);
    }
  });

  connection.on('session-disconnected', (sessionId: string) => {
    if (options.json) {
      console.log(JSON.stringify({
        event: 'pluginDisconnected',
        sessionId,
        timestamp: new Date().toISOString(),
      }));
    } else {
      console.log(`Plugin disconnected: ${sessionId}`);
    }
  });

  // Set up signal handlers
  const shutdownAsync = async () => {
    if (options.json) {
      console.log(JSON.stringify({ event: 'shuttingDown', timestamp: new Date().toISOString() }));
    } else {
      console.log('Shutting down...');
    }
    await connection.disconnectAsync();
    if (options.json) {
      console.log(JSON.stringify({ event: 'stopped', timestamp: new Date().toISOString() }));
    } else {
      console.log('Bridge host stopped.');
    }
    process.exit(0);
  };

  process.on('SIGTERM', () => void shutdownAsync());
  process.on('SIGINT', () => void shutdownAsync());
  process.on('SIGHUP', () => {
    /* ignore -- survive terminal close */
  });

  // Block until shutdown
  if (options.timeout) {
    // With timeout: auto-shutdown after idle period
    await new Promise<void>((resolve) => {
      setTimeout(resolve, options.timeout);
    });
    await connection.disconnectAsync();
  } else {
    // No timeout: block forever
    await new Promise<void>(() => {
      // Never resolves -- process runs until signal
    });
  }

  return { port: connection.port, event: 'stopped' };
}
