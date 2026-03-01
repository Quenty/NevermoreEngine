/**
 * Request/response correlation layer for matching outgoing server requests
 * to incoming plugin responses by requestId.
 */

interface PendingEntry<T> {
  resolve: (value: T) => void;
  reject: (error: Error) => void;
  timer: ReturnType<typeof setTimeout>;
}

export class PendingRequestMap<T> {
  private _pending = new Map<string, PendingEntry<T>>();

  /**
   * Register a pending request and return a promise that resolves when the
   * response arrives or rejects on timeout/cancellation. If a request with
   * the same ID is already pending, the new promise rejects immediately
   * without disturbing the existing one.
   */
  addRequestAsync(requestId: string, timeoutMs: number): Promise<T> {
    if (this._pending.has(requestId)) {
      return Promise.reject(
        new Error(`Request "${requestId}" is already pending`)
      );
    }

    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        this._pending.delete(requestId);
        reject(new Error(`Request "${requestId}" timed out after ${timeoutMs}ms`));
      }, timeoutMs);

      this._pending.set(requestId, { resolve, reject, timer });
    });
  }

  /**
   * Resolve a pending request with the given result. Unknown IDs are
   * silently ignored.
   */
  resolveRequest(requestId: string, result: T): void {
    const entry = this._pending.get(requestId);
    if (!entry) return;

    clearTimeout(entry.timer);
    this._pending.delete(requestId);
    entry.resolve(result);
  }

  /**
   * Reject a pending request with the given error. Unknown IDs are
   * silently ignored.
   */
  rejectRequest(requestId: string, error: Error): void {
    const entry = this._pending.get(requestId);
    if (!entry) return;

    clearTimeout(entry.timer);
    this._pending.delete(requestId);
    entry.reject(error);
  }

  /**
   * Cancel all pending requests, rejecting each with a cancellation error.
   */
  cancelAll(reason?: string): void {
    const message = reason ?? 'All pending requests cancelled';
    for (const [, entry] of this._pending) {
      clearTimeout(entry.timer);
      entry.reject(new Error(message));
    }
    this._pending.clear();
  }

  /** Number of currently pending requests. */
  get pendingCount(): number {
    return this._pending.size;
  }

  /** Whether a request with the given ID is currently pending. */
  hasPendingRequest(requestId: string): boolean {
    return this._pending.has(requestId);
  }
}
