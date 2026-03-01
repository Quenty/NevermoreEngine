/**
 * Action dispatcher for v2 protocol actions. Generates request IDs,
 * tracks pending requests, applies per-action-type timeouts, and
 * correlates incoming plugin responses to outgoing requests.
 *
 * Used by StudioBridgeServer for the v2 `performActionAsync` path.
 * The v1 `executeAsync` path bypasses this entirely.
 */

import { randomUUID } from 'crypto';
import { PendingRequestMap } from './pending-request-map.js';
import type { PluginMessage } from './web-socket-protocol.js';

// ---------------------------------------------------------------------------
// Default timeouts per action type (ms)
// ---------------------------------------------------------------------------

export const ACTION_TIMEOUTS: Record<string, number> = {
  queryState: 5_000,
  captureScreenshot: 15_000,
  queryDataModel: 10_000,
  queryLogs: 10_000,
  execute: 120_000,
  subscribe: 5_000,
  unsubscribe: 5_000,
};

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

export class ActionDispatcher {
  private _pendingRequests = new PendingRequestMap<PluginMessage>();

  /**
   * Create a new pending request for the given action type.
   * Returns the generated requestId and a promise that resolves when
   * the plugin responds (or rejects on timeout).
   */
  createRequestAsync(
    actionType: string,
    timeoutMs?: number,
  ): { requestId: string; responsePromise: Promise<PluginMessage> } {
    const requestId = randomUUID();
    const timeout = timeoutMs ?? ACTION_TIMEOUTS[actionType] ?? 30_000;
    const responsePromise = this._pendingRequests.addRequestAsync(requestId, timeout);

    return { requestId, responsePromise };
  }

  /**
   * Handle an incoming plugin message. If it has a requestId and matches
   * a pending request, resolves (or rejects for error type) the request.
   * Returns true if the message was consumed by the dispatcher.
   */
  handleResponse(message: PluginMessage): boolean {
    // Extract requestId from the message -- it may or may not exist
    const requestId = 'requestId' in message ? (message as any).requestId : undefined;

    if (typeof requestId !== 'string') {
      return false;
    }

    if (!this._pendingRequests.hasPendingRequest(requestId)) {
      return false;
    }

    if (message.type === 'error') {
      const errorMsg = message.payload.message ?? 'Unknown plugin error';
      const code = message.payload.code ?? 'INTERNAL_ERROR';
      this._pendingRequests.rejectRequest(
        requestId,
        new Error(`Plugin error [${code}]: ${errorMsg}`),
      );
      return true;
    }

    this._pendingRequests.resolveRequest(requestId, message);
    return true;
  }

  /**
   * Cancel all pending requests, rejecting each with the given reason.
   */
  cancelAll(reason?: string): void {
    this._pendingRequests.cancelAll(reason);
  }

  /** Number of currently pending requests. */
  get pendingCount(): number {
    return this._pendingRequests.pendingCount;
  }
}
