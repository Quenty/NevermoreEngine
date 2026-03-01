/**
 * Low-level WebSocket server with path-based routing. Handles HTTP server
 * creation, port binding, WebSocket upgrade for registered paths, and HTTP
 * GET for the /health endpoint. No business logic — it is a dumb pipe that
 * routes connections by URL path.
 */

import { createServer, type IncomingMessage, type ServerResponse, type Server } from 'http';
import type { Socket } from 'net';
import { WebSocketServer, WebSocket } from 'ws';
import { URL } from 'url';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export interface TransportServerOptions {
  /** Port to bind on. Default: 38741. Use 0 for ephemeral (test-friendly). */
  port?: number;
  /** Host to bind on. Default: 'localhost'. */
  host?: string;
}

export type ConnectionHandler = (ws: WebSocket, request: IncomingMessage) => void;
export type HttpHandler = (req: IncomingMessage, res: ServerResponse) => void;

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

const DEFAULT_PORT = 38741;
const DEFAULT_HOST = 'localhost';

export class TransportServer {
  private _httpServer: Server | undefined;
  private _wss: WebSocketServer | undefined;
  private _port = 0;
  private _isListening = false;
  private readonly _sockets = new Set<Socket>();

  private readonly _wsHandlers = new Map<string, ConnectionHandler>();
  private readonly _httpHandlers = new Map<string, HttpHandler>();

  /**
   * Start the WebSocket server. Binds to the specified port.
   * Uses `exclusive: false` for SO_REUSEADDR so the port can be reused
   * after a crash without waiting for TIME_WAIT.
   * Returns the actual bound port (important when port: 0 is used).
   */
  async startAsync(options?: TransportServerOptions): Promise<number> {
    if (this._isListening) {
      throw new Error('TransportServer is already listening');
    }

    const port = options?.port ?? DEFAULT_PORT;
    const host = options?.host ?? DEFAULT_HOST;

    this._httpServer = createServer((req, res) => {
      this._handleHttpRequest(req, res);
    });

    // Track all raw TCP sockets so forceCloseAsync() can destroy them
    this._httpServer.on('connection', (socket: Socket) => {
      this._sockets.add(socket);
      socket.on('close', () => {
        this._sockets.delete(socket);
      });
    });

    this._wss = new WebSocketServer({ noServer: true });

    this._httpServer.on('upgrade', (request, socket, head) => {
      const pathname = this._parsePath(request);
      const handler = this._wsHandlers.get(pathname);

      if (!handler) {
        socket.write('HTTP/1.1 404 Not Found\r\n\r\n');
        socket.destroy();
        return;
      }

      this._wss!.handleUpgrade(request, socket, head, (ws) => {
        handler(ws, request);
      });
    });

    return new Promise<number>((resolve, reject) => {
      const server = this._httpServer!;

      const onError = (err: NodeJS.ErrnoException) => {
        server.off('listening', onListening);
        if (err.code === 'EADDRINUSE') {
          reject(new Error(`Port ${port} is already in use`));
        } else {
          reject(err);
        }
      };

      const onListening = () => {
        server.off('error', onError);
        const addr = server.address();
        if (typeof addr === 'object' && addr !== null) {
          this._port = addr.port;
        }
        this._isListening = true;
        resolve(this._port);
      };

      server.once('error', onError);
      server.once('listening', onListening);
      // SO_REUSEADDR is enabled by default in Node's net module, allowing
      // the port to be rebound immediately after a process crash without
      // waiting for TIME_WAIT to expire. This is essential for host failover.
      server.listen(port, host, undefined, undefined);
    });
  }

  /**
   * Stop the server and close all connections.
   */
  async stopAsync(): Promise<void> {
    if (!this._isListening) {
      return;
    }
    this._isListening = false;

    // Terminate all WebSocket connections first
    if (this._wss) {
      for (const client of this._wss.clients) {
        client.terminate();
      }
    }

    // Close the WebSocket server
    if (this._wss) {
      await new Promise<void>((resolve) => {
        this._wss!.close(() => resolve());
      });
      this._wss = undefined;
    }

    // Close the HTTP server
    if (this._httpServer) {
      await new Promise<void>((resolve) => {
        this._httpServer!.close(() => resolve());
      });
      this._httpServer = undefined;
    }

    this._port = 0;
  }

  /** The actual port the server is bound to. */
  get port(): number {
    return this._port;
  }

  /** Whether the server is currently listening. */
  get isListening(): boolean {
    return this._isListening;
  }

  /**
   * Register a handler for WebSocket connections on a specific path.
   * Paths: '/plugin' for Studio plugins, '/client' for CLI clients.
   */
  onConnection(path: string, handler: ConnectionHandler): void {
    this._wsHandlers.set(path, handler);
  }

  /**
   * Register an HTTP request handler for a specific path.
   * Used for '/health' to handle plain HTTP GET requests.
   */
  onHttpRequest(path: string, handler: HttpHandler): void {
    this._httpHandlers.set(path, handler);
  }

  /**
   * Force-close the server by destroying all open TCP sockets immediately.
   * Unlike stopAsync(), this does not wait for graceful close handshakes.
   * Used during host shutdown to release the port as fast as possible.
   */
  async forceCloseAsync(): Promise<void> {
    if (!this._isListening) {
      return;
    }
    this._isListening = false;

    // Destroy all raw TCP sockets immediately
    for (const socket of this._sockets) {
      socket.destroy();
    }
    this._sockets.clear();

    // Terminate all WebSocket connections
    if (this._wss) {
      for (const client of this._wss.clients) {
        client.terminate();
      }
      await new Promise<void>((resolve) => {
        this._wss!.close(() => resolve());
      });
      this._wss = undefined;
    }

    // Close the HTTP server
    if (this._httpServer) {
      await new Promise<void>((resolve) => {
        this._httpServer!.close(() => resolve());
      });
      this._httpServer = undefined;
    }

    this._port = 0;
  }

  // -------------------------------------------------------------------------
  // Private
  // -------------------------------------------------------------------------

  private _parsePath(request: IncomingMessage): string {
    try {
      const url = new URL(request.url ?? '/', `http://${request.headers.host ?? 'localhost'}`);
      return url.pathname;
    } catch {
      return '/';
    }
  }

  private _handleHttpRequest(req: IncomingMessage, res: ServerResponse): void {
    const pathname = this._parsePath(req);
    const handler = this._httpHandlers.get(pathname);

    if (handler) {
      handler(req, res);
      return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
}
