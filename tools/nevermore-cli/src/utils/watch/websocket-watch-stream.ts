import { WebSocket } from 'ws';
import {
  type WatchStream,
  type WatchStreamEvent,
  type WatchStreamNotify,
  type WatchStreamReady,
  type WatchStreamResult,
  type WatchStreamOptions,
} from '@quenty/nevermore-deploy';

/**
 * The monitor was released, or its lease lapsed. Retrying cannot help, so this
 * ends the stream rather than backing off against something that is gone.
 */
const CLOSE_MONITOR_GONE = 4004;

/** Orderly shutdown on the service's side. Reconnect promptly, not as a fault. */
const CLOSE_GOING_AWAY = 1001;

/**
 * The service retires a connection roughly hourly so that reconnecting
 * re-verifies the token — a socket must not outlive a revoked credential.
 * Routine by design, so it reconnects promptly and is not reported as a drop.
 */
const CLOSE_REAUTHENTICATE = 4005;

/**
 * Handshake refusals worth explaining rather than retrying blindly.
 *
 * A websocket that fails to upgrade reports only "Unexpected server response:
 * <status>", which is the same message for a misconfigured proxy and an expired
 * token — two problems with nothing in common. These are the statuses the API
 * documents, each mapped to the thing that actually has to change.
 */
const HANDSHAKE_FAILURES: Record<
  number,
  { permanent: boolean; describe: () => string }
> = {
  401: {
    permanent: true,
    describe: () =>
      'The watch service rejected the token on the stream handshake. Set ' +
      'NEVERMORE_WATCH_TOKEN to a valid, unexpired GitHub token.',
  },
  404: {
    permanent: true,
    describe: () =>
      'The watch monitor was not found, or the token cannot write to the ' +
      'repository that owns it. A stream is readable only by a token with ' +
      'write access to that repository.',
  },
  426: {
    permanent: false,
    describe: () =>
      'The watch service answered the stream handshake with 426 Upgrade ' +
      'Required, which means it never saw an Upgrade header — this client ' +
      'sent one, so something in front of the service is stripping it. That ' +
      'is a proxy configuration problem on the service side (nginx needs ' +
      'proxy_http_version 1.1 plus the Upgrade and Connection headers ' +
      'forwarded), not something to fix here.',
  },
  429: {
    permanent: false,
    describe: () =>
      'Too many concurrent watch streams are open for this monitor. Close ' +
      'another `--watch` session, or wait for one to time out.',
  },
  503: {
    permanent: false,
    describe: () =>
      'The watch service is not accepting streams right now. Retrying.',
  },
};

const RECONNECT_BASE_MS = 1_000;
const RECONNECT_MAX_MS = 30_000;

/**
 * Floor under a prompt reconnect. A server that accepts, sends `ready` and
 * immediately closes would otherwise be reconnected to as fast as the loop can
 * spin — around a hundred connections a second, each costing the service a full
 * token verification. That is a stampede aimed at something already failing, so
 * even a "come back now" close waits this long.
 */
const RECONNECT_MIN_MS = 250;

/**
 * How long a connection must last to count as healthy enough to reset the
 * backoff. Receiving `ready` is not enough by itself: a crash-looping server
 * sends one every time, which would pin the delay at its minimum forever.
 */
const HEALTHY_CONNECTION_MS = 10_000;

/**
 * Answers the service's heartbeat at the application layer as well as the
 * protocol one. A proxy that terminates and re-originates the socket can eat
 * ping/pong control frames while happily forwarding text, which looks exactly
 * like a healthy connection until nothing arrives for an hour.
 */
const APP_PING_INTERVAL_MS = 30_000;

export interface WebSocketWatchStreamOptions {
  /**
   * The register endpoint this monitor was created against. The stream URL is
   * derived from it so the host is configured in exactly one place, and so no
   * service address is ever written down in this repo.
   */
  registerUrl: string;
  /** Injected in tests. */
  connect?: (url: string, headers: Record<string, string>) => WebSocket;
}

export class WebSocketWatchStream implements WatchStream {
  private readonly _registerUrl: string;
  private readonly _connect: (
    url: string,
    headers: Record<string, string>
  ) => WebSocket;

  public constructor(options: WebSocketWatchStreamOptions) {
    this._registerUrl = options.registerUrl;
    this._connect =
      options.connect ?? ((url, headers) => new WebSocket(url, { headers }));
  }

  public async runAsync(
    options: WatchStreamOptions
  ): Promise<WatchStreamResult> {
    const url = this._streamUrl(options.monitorId);

    let reconnects = 0;
    let notifications = 0;
    let attempt = 0;

    while (!options.signal.aborted) {
      const outcome = await this._holdAsync(url, options, (n) => {
        notifications += n;
      });

      if (outcome.ending === 'monitor-gone') {
        return {
          ending: 'monitor-gone',
          reason: outcome.reason,
          reconnects,
          notifications,
        };
      }
      if (outcome.ending === 'rejected') {
        return {
          ending: 'rejected',
          reason: outcome.reason,
          reconnects,
          notifications,
        };
      }
      if (options.signal.aborted) {
        break;
      }

      // A connection that carried `ready` *and* lasted proves the endpoint is
      // healthy, so the next drop backs off from scratch rather than inheriting
      // a delay from a problem that is over. Both halves matter: a server that
      // sends `ready` and then drops would otherwise never back off at all.
      const healthy =
        outcome.wasReady && outcome.livedMs >= HEALTHY_CONNECTION_MS;
      attempt = healthy ? 0 : attempt + 1;
      reconnects++;
      const delay = outcome.immediate
        ? RECONNECT_MIN_MS
        : Math.max(RECONNECT_MIN_MS, _backoffMs(attempt));
      // A retirement is scheduled maintenance rather than a drop; reporting it
      // would put an hourly warning in front of a developer for no reason.
      if (!outcome.routine) {
        options.handlers.onReconnect?.(reconnects, outcome.reason);
      }
      await _sleepAsync(delay, options.signal);
    }

    return { ending: 'aborted', reconnects, notifications };
  }

  /** `.../v1/register/30m/` and `.../v1/monitors/{id}/stream` share a root. */
  private _streamUrl(monitorId: string): string {
    const url = new URL(this._registerUrl);
    const marker = '/v1/register/';
    const index = url.pathname.indexOf(marker);
    if (index < 0) {
      throw new Error(
        `Cannot derive a watch stream URL from "${this._registerUrl}" — ` +
          `expected its path to contain "${marker}".`
      );
    }
    url.pathname = `${url.pathname.slice(
      0,
      index
    )}/v1/monitors/${encodeURIComponent(monitorId)}/stream`.replace(
      /\/{2,}/g,
      '/'
    );
    url.protocol = url.protocol === 'http:' ? 'ws:' : 'wss:';
    return url.toString();
  }

  private _holdAsync(
    url: string,
    options: WatchStreamOptions,
    countNotifications: (n: number) => void
  ): Promise<_HoldOutcome> {
    return new Promise<_HoldOutcome>((resolve) => {
      const socket = this._connect(url, {
        // Header rather than a query parameter, deliberately: a PAT in a URL
        // lands in every access log between here and the service.
        Authorization: `Bearer ${options.credential}`,
      });

      let ready = false;
      let settled = false;
      const openedAt = Date.now();
      let notifications = 0;
      let pinger: NodeJS.Timeout | undefined;

      // Handlers are async and messages arrive whenever they arrive, so they
      // are chained onto one tail. Two rebuilds of the same place running
      // concurrently would race each other's uploads.
      //
      // Every link swallows its own rejection. The port does not promise a
      // handler is safe, and a rejected tail would both strand `finish` — the
      // watch hanging forever — and take every later frame with it, since
      // `.then` on a rejected promise never runs.
      let tail: Promise<void> = Promise.resolve();
      const chain = (run: () => Promise<void>): void => {
        tail = tail.then(run).catch((err: unknown) => {
          options.handlers.onHandlerError?.(
            err instanceof Error ? err : new Error(String(err))
          );
        });
      };

      // Stamped here rather than at each call site, so a new way of ending a
      // connection cannot forget to report how long it lasted and silently
      // count itself healthy.
      const finish = (outcome: Omit<_HoldOutcome, 'livedMs'>) => {
        if (settled) {
          return;
        }
        settled = true;
        if (pinger) {
          clearInterval(pinger);
        }
        options.signal.removeEventListener('abort', onAbort);
        countNotifications(notifications);
        const settledOutcome: _HoldOutcome = {
          ...outcome,
          livedMs: Date.now() - openedAt,
        };
        // Let queued handlers drain before reporting, so a rebuild that was in
        // flight when the socket dropped still finishes and still records. A
        // rejected tail resolves too: a handler that threw has already been
        // reported, and must not strand the watch.
        void tail.then(
          () => resolve(settledOutcome),
          () => resolve(settledOutcome)
        );
      };

      const onAbort = () => {
        socket.close();
        finish({ ending: 'closed', reason: 'stopped', wasReady: ready });
      };
      options.signal.addEventListener('abort', onAbort, { once: true });

      socket.on('open', () => {
        // 'open' can still fire after an abort during CONNECTING, and an
        // interval installed then would never be cleared.
        if (settled) {
          return;
        }
        pinger = setInterval(() => {
          if (socket.readyState === WebSocket.OPEN) {
            socket.send(JSON.stringify({ type: 'ping' }));
          }
        }, APP_PING_INTERVAL_MS);
        pinger.unref?.();
      });

      socket.on('message', (data: { toString(): string }) => {
        let message: { type?: string } | undefined;
        try {
          message = JSON.parse(data.toString()) as { type?: string };
        } catch {
          // A frame we cannot parse is the service being newer than us, not a
          // reason to drop a working connection.
          return;
        }

        switch (message.type) {
          case 'ready':
            ready = true;
            chain(() =>
              options.handlers.onReadyAsync(message as WatchStreamReady)
            );
            break;
          case 'notify':
            notifications++;
            chain(() =>
              options.handlers.onNotifyAsync(message as WatchStreamNotify)
            );
            break;
          case 'event':
            options.handlers.onEvent?.(message as WatchStreamEvent);
            break;
          default:
            break;
        }
      });

      // Fires before 'error' when the upgrade itself was refused, and unlike
      // 'error' it carries the status — which is the only thing that tells a
      // stripped Upgrade header apart from a dead token.
      socket.on('unexpected-response', (_request, response) => {
        const status = response.statusCode ?? 0;
        const known = HANDSHAKE_FAILURES[status];
        // Registering this listener makes teardown ours: `ws` stops doing it.
        response.resume();
        response.destroy();
        finish({
          ending: known?.permanent ? 'rejected' : 'closed',
          reason: known
            ? known.describe()
            : `the stream handshake failed with ${status}`,
          wasReady: ready,
        });
      });

      socket.on('error', (err: Error) => {
        // The socket may still be half-open, and nothing else will close it
        // once we have stopped listening.
        socket.terminate();
        finish({ ending: 'closed', reason: err.message, wasReady: ready });
      });

      socket.on('close', (code: number, reason: Buffer) => {
        if (code === CLOSE_MONITOR_GONE) {
          finish({
            ending: 'monitor-gone',
            reason: reason.toString() || 'monitor released or lease expired',
            wasReady: ready,
          });
          return;
        }
        finish({
          ending: 'closed',
          reason: reason.toString() || `closed with ${code}`,
          wasReady: ready,
          immediate: code === CLOSE_GOING_AWAY || code === CLOSE_REAUTHENTICATE,
          routine: code === CLOSE_REAUTHENTICATE,
        });
      });
    });
  }
}

interface _HoldOutcome {
  ending: 'closed' | 'monitor-gone' | 'rejected';
  reason: string;
  /** Whether this connection got far enough to deliver its `ready` frame. */
  wasReady: boolean;
  /** How long the connection lasted, used to tell healthy from flapping. */
  livedMs: number;
  /** Set for a shutdown or retirement — "come back now" rather than a failure. */
  immediate?: boolean;
  /** Set when the close was scheduled maintenance and not worth reporting. */
  routine?: boolean;
}

function _backoffMs(attempt: number): number {
  return Math.min(RECONNECT_MAX_MS, RECONNECT_BASE_MS * 2 ** (attempt - 1));
}

function _sleepAsync(ms: number, signal: AbortSignal): Promise<void> {
  if (ms <= 0 || signal.aborted) {
    return Promise.resolve();
  }
  return new Promise((resolve) => {
    const timer = setTimeout(finish, ms);
    function finish() {
      clearTimeout(timer);
      signal.removeEventListener('abort', finish);
      resolve();
    }
    signal.addEventListener('abort', finish, { once: true });
  });
}
