import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { PendingRequestMap } from './pending-request-map.js';

describe('PendingRequestMap', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('happy path', () => {
    it('resolves the promise when resolveRequest is called', async () => {
      const map = new PendingRequestMap<string>();
      const promise = map.addRequestAsync('req-1', 5000);

      map.resolveRequest('req-1', 'hello');

      await expect(promise).resolves.toBe('hello');
    });

    it('resolves with an object value', async () => {
      const map = new PendingRequestMap<{ status: number }>();
      const promise = map.addRequestAsync('req-1', 5000);

      map.resolveRequest('req-1', { status: 200 });

      await expect(promise).resolves.toEqual({ status: 200 });
    });
  });

  describe('rejection', () => {
    it('rejects the promise when rejectRequest is called', async () => {
      const map = new PendingRequestMap<string>();
      const promise = map.addRequestAsync('req-1', 5000);

      map.rejectRequest('req-1', new Error('Something failed'));

      await expect(promise).rejects.toThrow('Something failed');
    });
  });

  describe('timeout', () => {
    it('rejects with timeout error after the specified duration', async () => {
      const map = new PendingRequestMap<string>();
      const promise = map.addRequestAsync('req-1', 1000);

      vi.advanceTimersByTime(1000);

      await expect(promise).rejects.toThrow('Request "req-1" timed out after 1000ms');
    });

    it('removes the entry from the map after timeout', async () => {
      const map = new PendingRequestMap<string>();
      const promise = map.addRequestAsync('req-1', 500);

      expect(map.hasPendingRequest('req-1')).toBe(true);

      vi.advanceTimersByTime(500);

      // Let the rejection propagate
      await promise.catch(() => {});

      expect(map.hasPendingRequest('req-1')).toBe(false);
      expect(map.pendingCount).toBe(0);
    });
  });

  describe('cancelAll', () => {
    it('rejects all pending requests', async () => {
      const map = new PendingRequestMap<string>();
      const p1 = map.addRequestAsync('req-1', 5000);
      const p2 = map.addRequestAsync('req-2', 5000);
      const p3 = map.addRequestAsync('req-3', 5000);

      map.cancelAll('session closed');

      await expect(p1).rejects.toThrow('session closed');
      await expect(p2).rejects.toThrow('session closed');
      await expect(p3).rejects.toThrow('session closed');
    });

    it('uses default message when no reason provided', async () => {
      const map = new PendingRequestMap<string>();
      const promise = map.addRequestAsync('req-1', 5000);

      map.cancelAll();

      await expect(promise).rejects.toThrow('All pending requests cancelled');
    });

    it('empties the map after cancellation', () => {
      const map = new PendingRequestMap<string>();
      map.addRequestAsync('req-1', 5000).catch(() => {});
      map.addRequestAsync('req-2', 5000).catch(() => {});

      map.cancelAll();

      expect(map.pendingCount).toBe(0);
      expect(map.hasPendingRequest('req-1')).toBe(false);
      expect(map.hasPendingRequest('req-2')).toBe(false);
    });
  });

  describe('unknown ID handling', () => {
    it('resolveRequest with unknown ID does not throw', () => {
      const map = new PendingRequestMap<string>();
      expect(() => map.resolveRequest('nonexistent', 'value')).not.toThrow();
    });

    it('rejectRequest with unknown ID does not throw', () => {
      const map = new PendingRequestMap<string>();
      expect(() => map.rejectRequest('nonexistent', new Error('err'))).not.toThrow();
    });
  });

  describe('duplicate ID', () => {
    it('rejects the second addRequestAsync immediately without disturbing the first', async () => {
      const map = new PendingRequestMap<string>();
      const first = map.addRequestAsync('req-1', 5000);
      const second = map.addRequestAsync('req-1', 5000);

      await expect(second).rejects.toThrow('Request "req-1" is already pending');

      // First should still be pending
      expect(map.hasPendingRequest('req-1')).toBe(true);

      // Resolve the first
      map.resolveRequest('req-1', 'success');
      await expect(first).resolves.toBe('success');
    });
  });

  describe('pendingCount', () => {
    it('starts at 0', () => {
      const map = new PendingRequestMap<string>();
      expect(map.pendingCount).toBe(0);
    });

    it('increments when requests are added', () => {
      const map = new PendingRequestMap<string>();
      map.addRequestAsync('req-1', 5000).catch(() => {});
      expect(map.pendingCount).toBe(1);

      map.addRequestAsync('req-2', 5000).catch(() => {});
      expect(map.pendingCount).toBe(2);
    });

    it('decrements when requests are resolved', () => {
      const map = new PendingRequestMap<string>();
      map.addRequestAsync('req-1', 5000).catch(() => {});
      map.addRequestAsync('req-2', 5000).catch(() => {});

      map.resolveRequest('req-1', 'done');
      expect(map.pendingCount).toBe(1);

      map.resolveRequest('req-2', 'done');
      expect(map.pendingCount).toBe(0);
    });

    it('decrements when requests are rejected', () => {
      const map = new PendingRequestMap<string>();
      map.addRequestAsync('req-1', 5000).catch(() => {});

      map.rejectRequest('req-1', new Error('fail'));
      expect(map.pendingCount).toBe(0);
    });

    it('decrements on timeout', async () => {
      const map = new PendingRequestMap<string>();
      const promise = map.addRequestAsync('req-1', 100);

      expect(map.pendingCount).toBe(1);

      vi.advanceTimersByTime(100);
      await promise.catch(() => {});

      expect(map.pendingCount).toBe(0);
    });
  });

  describe('hasPendingRequest', () => {
    it('returns true for a pending request', () => {
      const map = new PendingRequestMap<string>();
      map.addRequestAsync('req-1', 5000).catch(() => {});
      expect(map.hasPendingRequest('req-1')).toBe(true);
    });

    it('returns false for an unknown request', () => {
      const map = new PendingRequestMap<string>();
      expect(map.hasPendingRequest('req-1')).toBe(false);
    });

    it('returns false after resolve', () => {
      const map = new PendingRequestMap<string>();
      map.addRequestAsync('req-1', 5000).catch(() => {});

      map.resolveRequest('req-1', 'done');
      expect(map.hasPendingRequest('req-1')).toBe(false);
    });

    it('returns false after reject', () => {
      const map = new PendingRequestMap<string>();
      map.addRequestAsync('req-1', 5000).catch(() => {});

      map.rejectRequest('req-1', new Error('fail'));
      expect(map.hasPendingRequest('req-1')).toBe(false);
    });

    it('returns false after timeout', async () => {
      const map = new PendingRequestMap<string>();
      const promise = map.addRequestAsync('req-1', 200);

      vi.advanceTimersByTime(200);
      await promise.catch(() => {});

      expect(map.hasPendingRequest('req-1')).toBe(false);
    });
  });

  describe('timer cleanup', () => {
    it('clears the timeout when resolved before expiry', () => {
      const map = new PendingRequestMap<string>();
      map.addRequestAsync('req-1', 5000).catch(() => {});

      map.resolveRequest('req-1', 'done');

      // Advancing past the original timeout should not cause issues
      vi.advanceTimersByTime(10000);
      expect(map.pendingCount).toBe(0);
    });

    it('clears the timeout when rejected before expiry', () => {
      const map = new PendingRequestMap<string>();
      map.addRequestAsync('req-1', 5000).catch(() => {});

      map.rejectRequest('req-1', new Error('early'));

      vi.advanceTimersByTime(10000);
      expect(map.pendingCount).toBe(0);
    });

    it('clears all timers on cancelAll', () => {
      const map = new PendingRequestMap<string>();
      map.addRequestAsync('req-1', 5000).catch(() => {});
      map.addRequestAsync('req-2', 5000).catch(() => {});

      map.cancelAll();

      vi.advanceTimersByTime(10000);
      expect(map.pendingCount).toBe(0);
    });
  });
});
