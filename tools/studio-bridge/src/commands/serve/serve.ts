/**
 * `serve` — start a dedicated bridge host process that stays alive,
 * accepting plugin and client connections.
 */

import { defineCommand } from '../framework/define-command.js';
import { arg } from '../framework/arg-builder.js';
import { BridgeConnection } from '../../bridge/index.js';
import type { BridgeSession } from '../../bridge/index.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ServeOptions {
  port?: number;
  json?: boolean;
  timeout?: number;
}

export interface ServeResult {
  port: number;
  event: string;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const serveCommand = defineCommand<ServeOptions, ServeResult>({
  group: null,
  name: 'serve',
  description: 'Start the bridge server',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {
    port: arg.option({ description: 'Port to listen on (default: 38741)', type: 'number' }),
    json: arg.flag({ description: 'Output events as JSON lines' }),
    timeout: arg.option({ description: 'Auto-shutdown after N milliseconds', type: 'number' }),
  },
  handler: async (args) => serveHandlerAsync(args),
});
