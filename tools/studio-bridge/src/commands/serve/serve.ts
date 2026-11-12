/**
 * `serve` — start a dedicated bridge host process that stays alive,
 * accepting plugin and client connections.
 */

import * as fs from 'fs';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { formatDurationMs } from '@quenty/cli-output-helpers/cli-utils';
import { defineCommand } from '../framework/define-command.js';
import { arg } from '../framework/arg-builder.js';
import { BridgeConnection, getHostLogPath } from '../../bridge/index.js';
import type { BridgeSession } from '../../bridge/index.js';
import { isJsonOutputEnabled } from '../../cli/cli-output-context.js';
import { parseDurationSeconds } from '../shared/duration.js';
import { IdleExit } from './idle-exit.js';
import {
  invalidInput,
  StudioBridgeError,
} from '../../messages/studio-bridge-error.js';

export interface ServeOptions {
  port?: number;
  json?: boolean;
  timeout?: number;
  idleTimeout?: string;
  autoStarted?: boolean;
}

const NO_SESSION_TIMEOUT_MS = 2 * 60_000;
const MAX_LOG_BYTES = 1_000_000;

export interface ServeResult {
  port: number;
  event: string;
  timestamp: string;
  summary: string;
}

/** Blocks until shutdown signal or timeout. */
export async function serveHandlerAsync(
  options: ServeOptions = {}
): Promise<ServeResult> {
  const port = options.port ?? 38741;
  options = { ...options, json: options.json || isJsonOutputEnabled() };
  const idleTimeoutMs =
    options.idleTimeout !== undefined
      ? parseDurationSeconds(options.idleTimeout, '--idle-timeout') * 1000
      : undefined;
  if (idleTimeoutMs !== undefined && idleTimeoutMs <= 0) {
    throw invalidInput(
      '--idle-timeout 0 would stop the bridge host as soon as it starts.',
      'Give a longer time, e.g. --idle-timeout 10m, or leave it out to never exit.'
    );
  }
  const logPath = options.autoStarted ? getHostLogPath(port) : undefined;
  if (logPath) {
    redirectOutputToFile(logPath);
  }

  const alreadyRunning = new StudioBridgeError({
    code: 'HOST_ALREADY_RUNNING',
    message: `A bridge host is already running on port ${port}, so commands already use it.`,
    fix: 'Use --port to start another one on a different port.',
  });

  let connection: BridgeConnection;
  try {
    connection = await BridgeConnection.connectAsync({
      port,
      keepAlive: true,
      replaceStaleHost: false,
      ...(idleTimeoutMs !== undefined || logPath
        ? {
            hostDetails: {
              autoStarted: options.autoStarted,
              idleTimeoutMs,
              logPath,
            },
          }
        : {}),
    });
  } catch (err: unknown) {
    if (
      err instanceof Error &&
      'code' in err &&
      (err as NodeJS.ErrnoException).code === 'EADDRINUSE'
    ) {
      throw alreadyRunning;
    }
    throw err;
  }

  if (connection.role !== 'host') {
    await connection.disconnectAsync();
    throw alreadyRunning;
  }

  const listeningPort = connection.port;

  // Log startup
  if (options.json) {
    console.log(
      JSON.stringify({
        event: 'started',
        port: connection.port,
        timestamp: new Date().toISOString(),
      })
    );
  } else {
    console.log(
      `Bridge host listening on port ${connection.port} (pid ${process.pid})${
        idleTimeoutMs !== undefined
          ? `, exits after ${formatDurationMs(idleTimeoutMs)} unused`
          : ''
      }`
    );
  }

  // Set up event listeners for session changes
  connection.on('session-connected', (session: BridgeSession) => {
    if (options.json) {
      console.log(
        JSON.stringify({
          event: 'pluginConnected',
          sessionId: session.info.sessionId,
          context: session.info.context,
          timestamp: new Date().toISOString(),
        })
      );
    } else {
      console.log(
        `Plugin connected: ${session.info.sessionId} (${session.info.context})`
      );
    }
  });

  connection.on('session-disconnected', (sessionId: string) => {
    if (options.json) {
      console.log(
        JSON.stringify({
          event: 'pluginDisconnected',
          sessionId,
          timestamp: new Date().toISOString(),
        })
      );
    } else {
      console.log(`Plugin disconnected: ${sessionId}`);
    }
  });

  // Set up signal handlers
  const shutdownAsync = async () => {
    if (options.json) {
      console.log(
        JSON.stringify({
          event: 'shuttingDown',
          timestamp: new Date().toISOString(),
        })
      );
    } else {
      console.log('Shutting down...');
    }
    await connection.disconnectAsync();
    if (options.json) {
      console.log(
        JSON.stringify({
          event: 'stopped',
          timestamp: new Date().toISOString(),
        })
      );
    } else {
      console.log('Bridge host stopped.');
    }
    process.exit(0);
  };

  if (idleTimeoutMs !== undefined) {
    const idleExit = new IdleExit({
      clientIdleMs: idleTimeoutMs,
      noSessionMs: Math.min(NO_SESSION_TIMEOUT_MS, idleTimeoutMs),
      getClientCount: () => connection.clientCount,
      getSessionCount: () => connection.listSessions().length,
      onIdle: (reason) => {
        console.log(`Exiting: ${reason}`);
        void shutdownAsync();
      },
    });
    connection.on('client-activity', () => idleExit.noteClientActivity());
    connection.on('session-connected', () => idleExit.noteSessionsChanged());
    connection.on('session-disconnected', () => idleExit.noteSessionsChanged());
    idleExit.start();
  }

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

  return {
    port: listeningPort,
    event: 'stopped',
    timestamp: new Date().toISOString(),
    summary: 'Bridge host stopped.',
  };
}

function redirectOutputToFile(logPath: string): void {
  fs.mkdirSync(path.dirname(logPath), { recursive: true });
  try {
    if (fs.statSync(logPath).size > MAX_LOG_BYTES) {
      fs.rmSync(logPath);
    }
  } catch {}

  const write = createLogWriter(logPath);
  process.stdout.write = write as typeof process.stdout.write;
  process.stderr.write = write as typeof process.stderr.write;
}

type WriteCallback = (err?: Error | null) => void;

export function createLogWriter(
  logPath: string
): (
  chunk: string | Uint8Array,
  encodingOrCallback?: BufferEncoding | WriteCallback,
  callback?: WriteCallback
) => boolean {
  return (chunk, encodingOrCallback, callback) => {
    const encoding =
      typeof encodingOrCallback === 'string' ? encodingOrCallback : undefined;
    const done =
      typeof encodingOrCallback === 'function' ? encodingOrCallback : callback;

    const raw =
      typeof chunk === 'string'
        ? Buffer.from(chunk, encoding).toString('utf8')
        : Buffer.from(chunk).toString('utf8');
    const text = OutputHelper.stripAnsi(raw).replace(/\n$/, '');
    const stamp = `${new Date().toISOString()} [${process.pid}] `;
    let error: Error | null = null;
    try {
      fs.appendFileSync(
        logPath,
        text
          .split('\n')
          .map((line) => stamp + line)
          .join('\n') + '\n'
      );
    } catch (err) {
      error = err instanceof Error ? err : new Error(String(err));
    }
    if (done) {
      process.nextTick(done, error);
    }
    return true;
  };
}

export const serveCommand = defineCommand<ServeOptions, ServeResult>({
  group: null,
  name: 'serve',
  description:
    'Start the bridge server (optional: a command that finds none starts one in the background, which exits once unused)',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {
    port: arg.option({
      description: 'Port to listen on (default: 38741)',
      type: 'number',
    }),
    json: arg.flag({ description: 'Output events as JSON lines' }),
    timeout: arg.option({
      description: 'Auto-shutdown after N milliseconds',
      type: 'number',
    }),
    idleTimeout: arg.option({
      description:
        'Exit after this long with no CLI command using it (e.g. 10m), or after 2m (at most) with no Studio connected. Default: never',
    }),
    autoStarted: arg.flag({
      description: 'Started in the background by a command: log to a file',
      hidden: true,
    }),
  },
  handler: async (args) => serveHandlerAsync(args),
});
