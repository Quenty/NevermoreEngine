/**
 * Being told a base place moved, rather than asking.
 *
 * A monitor whose watches carry a `notify` action delivers to whoever is
 * holding its stream instead of dispatching a workflow. That is the shape a
 * local `--watch` wants: the rebuild belongs in the terminal the developer is
 * looking at, not on a runner.
 *
 * Declared here as a port, like `WatchRegistry`, so this package keeps the
 * rules about what a stream means while the socket itself lives in the CLI.
 */

/** One watch's state, as the service currently sees it. */
export interface WatchStreamStatus {
  name: string;
  sourceId: string;
  state: 'pending' | 'up-to-date' | 'drifted' | 'dispatching' | 'failed';
  /**
   * What `baselineVersion` and `currentVersion` are written in.
   *
   * For a Roblox place this is the asset-delivery content hash, which is *not*
   * the Open Cloud place version the lock file records. Reported by the service
   * precisely so a caller can tell before comparing the two.
   */
  versionTokenKind?: string;
  /** Version the service believes the subscriber last built from. */
  baselineVersion: string | null;
  /** Version the source is actually at now. Null before the first poll. */
  currentVersion: string | null;
  /**
   * Why the last *dispatch* failed. Says nothing about whether the source can
   * be read — that is `sourceError`, and conflating them is why an unreadable
   * place used to look healthy.
   */
  lastError?: string | null;
  /** Why the source could not be *read*, and how many times running. */
  sourceError?: string | null;
  sourceConsecutiveFailures?: number;
}

/**
 * The first frame on every connection, and the reason nothing is replayed.
 *
 * It carries each watch's currently observed version, so a client that was
 * offline reconciles by comparing this against its own lock file rather than
 * being handed a queue of changes the service guessed it had missed. Delivered
 * again on every reconnect, which makes it the single place a client has to
 * decide what is stale.
 */
export interface WatchStreamReady {
  type: 'ready';
  monitorId: string;
  repository: string;
  name: string;
  leaseExpiresAt: string;
  /** Server clock, so a client can tell how far its own has drifted. */
  serverTime: string;
  watches: WatchStreamStatus[];
}

/** A `notify` action firing: this source moved and the rebuild is yours to do. */
export interface WatchStreamNotify {
  type: 'notify';
  watchName: string;
  sourceId: string;
  /** Null only when a forced trigger fired before the source was ever polled. */
  version: string | null;
  previousVersion: string | null;
  /** The action's opaque payload, forwarded verbatim. */
  payload: Record<string, string>;
  at: string;
}

/** The monitor's event log, tailed live. Informational; nothing acts on it. */
export interface WatchStreamEvent {
  type: 'event';
  event: {
    id: number;
    watchName: string | null;
    type: string;
    message: string;
    createdAt: string;
  };
}

export interface WatchStreamHandlers {
  /**
   * Called on connect and on every reconnect. This is the reconcile point: the
   * client compares each status against what it has actually built and decides
   * for itself what needs rebuilding.
   */
  onReadyAsync(message: WatchStreamReady): Promise<void>;
  onNotifyAsync(message: WatchStreamNotify): Promise<void>;
  onEvent?(message: WatchStreamEvent): void;
  /** A connection dropped and the stream is about to retry. Reporting only. */
  onReconnect?(attempt: number, reason: string): void;
  /**
   * A handler above threw.
   *
   * The stream swallows it rather than letting it escape: an unhandled
   * rejection would strand the watch and, under Node's default, kill the
   * process. This is the seam for saying so.
   */
  onHandlerError?(error: Error): void;
}

export interface WatchStreamOptions {
  monitorId: string;
  /** Same bearer token registration used; the service has no other identity. */
  credential: string;
  signal: AbortSignal;
  handlers: WatchStreamHandlers;
}

/**
 * Why the stream stopped.
 *
 * `monitor-gone` is its own outcome because it is not a fault: a lease that
 * lapsed or a monitor that was released is a finished watch, and retrying the
 * socket would just fail forever against something that no longer exists.
 *
 * `rejected` is the handshake being refused for a reason this process cannot
 * outlast — a token that cannot read the monitor. Retrying that is not
 * resilience, it is a loop printing the same error until someone notices.
 */
export type WatchStreamEnding = 'aborted' | 'monitor-gone' | 'rejected';

export interface WatchStreamResult {
  ending: WatchStreamEnding;
  /** Why, when the ending is one the caller should explain. Human-facing. */
  reason?: string;
  /** Connections after the first. Worth reporting; a flapping link is a symptom. */
  reconnects: number;
  notifications: number;
}

export interface WatchStream {
  /**
   * Hold the stream until the signal aborts or the monitor goes away.
   *
   * Reconnection belongs to the implementation, not the caller, precisely
   * because every reconnect re-delivers `ready` — keeping the retry here is
   * what guarantees a client cannot skip the reconcile after a dropped link.
   */
  runAsync(options: WatchStreamOptions): Promise<WatchStreamResult>;
}
