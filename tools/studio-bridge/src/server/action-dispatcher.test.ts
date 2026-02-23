/**
 * Unit tests for ActionDispatcher -- validates request creation, response
 * handling, timeout behavior, error handling, and cancel-all functionality.
 */

import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest';
import { ActionDispatcher, ACTION_TIMEOUTS } from './action-dispatcher.js';
import type { PluginMessage } from './web-socket-protocol.js';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('ActionDispatcher', () => {
  let dispatcher: ActionDispatcher;

  beforeEach(() => {
    vi.useFakeTimers();
    dispatcher = new ActionDispatcher();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  // -----------------------------------------------------------------------
  // Request creation
  // -----------------------------------------------------------------------

  describe('createRequestAsync', () => {
    it('generates a unique requestId', () => {
      const req1 = dispatcher.createRequestAsync('queryState');
      const req2 = dispatcher.createRequestAsync('queryState');

      expect(req1.requestId).not.toBe(req2.requestId);
      expect(typeof req1.requestId).toBe('string');
      expect(req1.requestId.length).toBeGreaterThan(0);
    });

    it('returns a promise that can be resolved', async () => {
      const { requestId, responsePromise } = dispatcher.createRequestAsync('queryState');

      const response: PluginMessage = {
        type: 'stateResult',
        sessionId: 'session-1',
        requestId,
        payload: { state: 'Edit', placeId: 0, placeName: 'Test', gameId: 0 },
      };

      // Resolve via handleResponse
      const consumed = dispatcher.handleResponse(response);
      expect(consumed).toBe(true);

      const result = await responsePromise;
      expect(result.type).toBe('stateResult');
    });

    it('increments pendingCount', () => {
      expect(dispatcher.pendingCount).toBe(0);

      dispatcher.createRequestAsync('queryState');
      expect(dispatcher.pendingCount).toBe(1);

      dispatcher.createRequestAsync('captureScreenshot');
      expect(dispatcher.pendingCount).toBe(2);
    });
  });

  // -----------------------------------------------------------------------
  // Timeout
  // -----------------------------------------------------------------------

  describe('timeout', () => {
    it('uses default timeout for known action type', async () => {
      const { responsePromise } = dispatcher.createRequestAsync('queryState');

      // Advance time just past the queryState timeout
      vi.advanceTimersByTime(ACTION_TIMEOUTS.queryState + 100);

      await expect(responsePromise).rejects.toThrow('timed out');
    });

    it('uses custom timeout when provided', async () => {
      const { responsePromise } = dispatcher.createRequestAsync('queryState', 500);

      vi.advanceTimersByTime(600);

      await expect(responsePromise).rejects.toThrow('timed out');
    });

    it('does not reject before timeout', async () => {
      const { requestId, responsePromise } = dispatcher.createRequestAsync('queryState');

      // Advance time to just before the timeout
      vi.advanceTimersByTime(ACTION_TIMEOUTS.queryState - 100);

      // Should still be pending
      expect(dispatcher.pendingCount).toBe(1);

      // Now resolve it
      dispatcher.handleResponse({
        type: 'stateResult',
        sessionId: 'session-1',
        requestId,
        payload: { state: 'Edit', placeId: 0, placeName: 'Test', gameId: 0 },
      });

      const result = await responsePromise;
      expect(result.type).toBe('stateResult');
    });

    it('uses 30s fallback for unknown action type', async () => {
      const { responsePromise } = dispatcher.createRequestAsync('unknownAction');

      vi.advanceTimersByTime(31_000);

      await expect(responsePromise).rejects.toThrow('timed out');
    });
  });

  // -----------------------------------------------------------------------
  // Response handling
  // -----------------------------------------------------------------------

  describe('handleResponse', () => {
    it('resolves the matching pending request', async () => {
      const { requestId, responsePromise } = dispatcher.createRequestAsync('captureScreenshot');

      const response: PluginMessage = {
        type: 'screenshotResult',
        sessionId: 'session-1',
        requestId,
        payload: { data: 'base64', format: 'png', width: 800, height: 600 },
      };

      const consumed = dispatcher.handleResponse(response);
      expect(consumed).toBe(true);
      expect(dispatcher.pendingCount).toBe(0);

      const result = await responsePromise;
      expect(result.type).toBe('screenshotResult');
    });

    it('returns false for messages without requestId', () => {
      const consumed = dispatcher.handleResponse({
        type: 'heartbeat',
        sessionId: 'session-1',
        payload: { uptimeMs: 1000, state: 'Edit', pendingRequests: 0 },
      });

      expect(consumed).toBe(false);
    });

    it('returns false for messages with unknown requestId', () => {
      const consumed = dispatcher.handleResponse({
        type: 'stateResult',
        sessionId: 'session-1',
        requestId: 'nonexistent-request',
        payload: { state: 'Edit', placeId: 0, placeName: 'Test', gameId: 0 },
      });

      expect(consumed).toBe(false);
    });

    it('rejects pending request when plugin sends error response', async () => {
      const { requestId, responsePromise } = dispatcher.createRequestAsync('queryDataModel');

      const errorResponse: PluginMessage = {
        type: 'error',
        sessionId: 'session-1',
        requestId,
        payload: {
          code: 'INSTANCE_NOT_FOUND',
          message: 'Instance not found at path game.NonExistent',
        },
      };

      const consumed = dispatcher.handleResponse(errorResponse);
      expect(consumed).toBe(true);

      await expect(responsePromise).rejects.toThrow('INSTANCE_NOT_FOUND');
      await expect(responsePromise).rejects.toThrow('Instance not found');
    });

    it('handles multiple concurrent requests independently', async () => {
      const req1 = dispatcher.createRequestAsync('queryState');
      const req2 = dispatcher.createRequestAsync('captureScreenshot');

      expect(dispatcher.pendingCount).toBe(2);

      // Resolve req2 first
      dispatcher.handleResponse({
        type: 'screenshotResult',
        sessionId: 'session-1',
        requestId: req2.requestId,
        payload: { data: 'img', format: 'png', width: 100, height: 100 },
      });

      expect(dispatcher.pendingCount).toBe(1);

      // Resolve req1
      dispatcher.handleResponse({
        type: 'stateResult',
        sessionId: 'session-1',
        requestId: req1.requestId,
        payload: { state: 'Play', placeId: 1, placeName: 'Place', gameId: 2 },
      });

      expect(dispatcher.pendingCount).toBe(0);

      const result1 = await req1.responsePromise;
      const result2 = await req2.responsePromise;

      expect(result1.type).toBe('stateResult');
      expect(result2.type).toBe('screenshotResult');
    });
  });

  // -----------------------------------------------------------------------
  // Cancel all
  // -----------------------------------------------------------------------

  describe('cancelAll', () => {
    it('rejects all pending requests', async () => {
      const req1 = dispatcher.createRequestAsync('queryState');
      const req2 = dispatcher.createRequestAsync('captureScreenshot');

      dispatcher.cancelAll('Server shutting down');

      expect(dispatcher.pendingCount).toBe(0);

      await expect(req1.responsePromise).rejects.toThrow('Server shutting down');
      await expect(req2.responsePromise).rejects.toThrow('Server shutting down');
    });

    it('uses default message when no reason provided', async () => {
      const { responsePromise } = dispatcher.createRequestAsync('queryState');

      dispatcher.cancelAll();

      await expect(responsePromise).rejects.toThrow('cancelled');
    });

    it('is safe to call when no requests pending', () => {
      expect(() => dispatcher.cancelAll()).not.toThrow();
    });
  });
});
