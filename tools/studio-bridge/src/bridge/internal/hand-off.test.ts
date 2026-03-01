/**
 * Unit tests for HandOffManager — validates the takeover state machine
 * transitions, jitter computation, and retry logic using injected
 * dependencies (no real network).
 */

import { describe, it, expect, vi } from 'vitest';
import {
  HandOffManager,
  computeTakeoverJitterMs,
  type HandOffDependencies,
  type HandOffLogEntry,
} from './hand-off.js';
import { HostUnreachableError } from '../types.js';
import { createHealthHandler } from './health-endpoint.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockDeps(overrides: Partial<HandOffDependencies> = {}): HandOffDependencies {
  return {
    tryBindAsync: overrides.tryBindAsync ?? vi.fn().mockResolvedValue(true),
    tryConnectAsClientAsync: overrides.tryConnectAsClientAsync ?? vi.fn().mockResolvedValue(false),
    delay: overrides.delay ?? vi.fn().mockResolvedValue(undefined),
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('HandOffManager', () => {
  describe('state machine transitions', () => {
    it('starts in connected state', () => {
      const deps = createMockDeps();
      const manager = new HandOffManager({ port: 38741, deps });

      expect(manager.state).toBe('connected');
    });

    it('transitions to detecting-failure on HostTransferNotice', () => {
      const deps = createMockDeps();
      const manager = new HandOffManager({ port: 38741, deps });

      manager.onHostTransferNotice();

      expect(manager.state).toBe('detecting-failure');
    });

    it('graceful path: skips jitter, transitions to promoted on bind success', async () => {
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockResolvedValue(true),
      });
      const manager = new HandOffManager({ port: 38741, deps });

      manager.onHostTransferNotice();
      const result = await manager.onHostDisconnectedAsync();

      expect(result).toBe('promoted');
      expect(manager.state).toBe('promoted');
      // Delay should not have been called with any jitter value > 0
      expect(deps.delay).not.toHaveBeenCalled();
    });

    it('crash path: applies jitter before takeover attempt', async () => {
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockResolvedValue(true),
        delay: vi.fn().mockResolvedValue(undefined),
      });
      const manager = new HandOffManager({ port: 38741, deps });

      // Mock Math.random to return a known value
      const randomSpy = vi.spyOn(Math, 'random').mockReturnValue(0.5);

      // Do NOT call onHostTransferNotice — this simulates a crash
      const result = await manager.onHostDisconnectedAsync();

      expect(result).toBe('promoted');
      expect(manager.state).toBe('promoted');
      // Should have called delay with jitter (0.5 * 500 = 250ms)
      expect(deps.delay).toHaveBeenCalledWith(250);

      randomSpy.mockRestore();
    });

    it('falls back to client when bind fails and another host exists', async () => {
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockResolvedValue(false),
        tryConnectAsClientAsync: vi.fn().mockResolvedValue(true),
      });
      const manager = new HandOffManager({ port: 38741, deps });

      manager.onHostTransferNotice();
      const result = await manager.onHostDisconnectedAsync();

      expect(result).toBe('fell-back-to-client');
      expect(manager.state).toBe('fell-back-to-client');
    });

    it('retries when bind fails and no host reachable', async () => {
      let bindCallCount = 0;
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockImplementation(async () => {
          bindCallCount++;
          // Succeed on the 3rd attempt
          return bindCallCount >= 3;
        }),
        tryConnectAsClientAsync: vi.fn().mockResolvedValue(false),
        delay: vi.fn().mockResolvedValue(undefined),
      });
      const manager = new HandOffManager({ port: 38741, deps });

      manager.onHostTransferNotice();
      const result = await manager.onHostDisconnectedAsync();

      expect(result).toBe('promoted');
      expect(manager.state).toBe('promoted');
      expect(deps.tryBindAsync).toHaveBeenCalledTimes(3);
      // delay should have been called for retry waits (2 retries before success)
      expect(deps.delay).toHaveBeenCalledTimes(2);
      expect(deps.delay).toHaveBeenCalledWith(1_000);
    });

    it('throws HostUnreachableError after 10 failed retries', async () => {
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockResolvedValue(false),
        tryConnectAsClientAsync: vi.fn().mockResolvedValue(false),
        delay: vi.fn().mockResolvedValue(undefined),
      });
      const manager = new HandOffManager({ port: 38741, deps });

      manager.onHostTransferNotice();

      await expect(manager.onHostDisconnectedAsync()).rejects.toThrow(HostUnreachableError);
      expect(deps.tryBindAsync).toHaveBeenCalledTimes(10);
      expect(deps.tryConnectAsClientAsync).toHaveBeenCalledTimes(10);
      // 9 retry delays (not called after the last failed attempt)
      expect(deps.delay).toHaveBeenCalledTimes(9);
    });

    it('transitions through taking-over before reaching promoted', async () => {
      const states: string[] = [];
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockImplementation(async () => {
          states.push(manager.state);
          return true;
        }),
      });
      const manager = new HandOffManager({ port: 38741, deps });

      manager.onHostTransferNotice();
      await manager.onHostDisconnectedAsync();

      expect(states).toContain('taking-over');
      expect(manager.state).toBe('promoted');
    });

    it('transitions through taking-over before reaching fell-back-to-client', async () => {
      const states: string[] = [];
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockImplementation(async () => {
          states.push(manager.state);
          return false;
        }),
        tryConnectAsClientAsync: vi.fn().mockResolvedValue(true),
      });
      const manager = new HandOffManager({ port: 38741, deps });

      manager.onHostTransferNotice();
      await manager.onHostDisconnectedAsync();

      expect(states).toContain('taking-over');
      expect(manager.state).toBe('fell-back-to-client');
    });
  });

  describe('computeTakeoverJitterMs', () => {
    it('returns 0 for graceful shutdown', () => {
      expect(computeTakeoverJitterMs({ graceful: true })).toBe(0);
    });

    it('returns values in [0, 500] for crash', () => {
      // Run multiple times to verify range
      for (let i = 0; i < 100; i++) {
        const jitter = computeTakeoverJitterMs({ graceful: false });
        expect(jitter).toBeGreaterThanOrEqual(0);
        expect(jitter).toBeLessThanOrEqual(500);
      }
    });

    it('uses Math.random for crash jitter', () => {
      const randomSpy = vi.spyOn(Math, 'random').mockReturnValue(0.8);

      const jitter = computeTakeoverJitterMs({ graceful: false });
      expect(jitter).toBe(400); // 0.8 * 500

      randomSpy.mockRestore();
    });
  });

  describe('port parameter', () => {
    it('passes the configured port to tryBindAsync', async () => {
      const tryBindAsync = vi.fn().mockResolvedValue(true);
      const deps = createMockDeps({ tryBindAsync });
      const manager = new HandOffManager({ port: 12345, deps });

      manager.onHostTransferNotice();
      await manager.onHostDisconnectedAsync();

      expect(tryBindAsync).toHaveBeenCalledWith(12345);
    });

    it('passes the configured port to tryConnectAsClientAsync', async () => {
      const tryConnectAsClientAsync = vi.fn().mockResolvedValue(true);
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockResolvedValue(false),
        tryConnectAsClientAsync,
      });
      const manager = new HandOffManager({ port: 54321, deps });

      manager.onHostTransferNotice();
      await manager.onHostDisconnectedAsync();

      expect(tryConnectAsClientAsync).toHaveBeenCalledWith(54321);
    });
  });

  // -------------------------------------------------------------------------
  // Observability: structured debug logging (Task 1.10)
  // -------------------------------------------------------------------------

  describe('structured debug logging', () => {
    it('logs state transition on HostTransferNotice', () => {
      const logger = vi.fn();
      const deps = createMockDeps();
      const manager = new HandOffManager({ port: 38741, deps, logger });

      manager.onHostTransferNotice();

      expect(logger).toHaveBeenCalledTimes(1);
      const entry: HandOffLogEntry = logger.mock.calls[0][0];
      expect(entry.oldState).toBe('connected');
      expect(entry.newState).toBe('detecting-failure');
      expect(entry.reason).toBe('host-transfer-notice');
      expect(entry.timestamp).toBeDefined();
    });

    it('logs state transitions during graceful promotion', async () => {
      const logger = vi.fn();
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockResolvedValue(true),
      });
      const manager = new HandOffManager({ port: 38741, deps, logger });

      manager.onHostTransferNotice();
      await manager.onHostDisconnectedAsync();

      // Should have logs: host-transfer-notice, graceful-disconnect, bind-success
      const reasons = logger.mock.calls.map((c: any[]) => c[0].reason);
      expect(reasons).toContain('host-transfer-notice');
      expect(reasons).toContain('graceful-disconnect');
      expect(reasons).toContain('bind-success');
    });

    it('logs crash jitter when not graceful', async () => {
      const logger = vi.fn();
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockResolvedValue(true),
        delay: vi.fn().mockResolvedValue(undefined),
      });
      const manager = new HandOffManager({ port: 38741, deps, logger });

      const randomSpy = vi.spyOn(Math, 'random').mockReturnValue(0.5);
      await manager.onHostDisconnectedAsync();
      randomSpy.mockRestore();

      const reasons = logger.mock.calls.map((c: any[]) => c[0].reason);
      expect(reasons).toContain('crash-jitter');
      expect(reasons).toContain('crash-detected');
    });

    it('logs retry attempts when bind and connect fail', async () => {
      const logger = vi.fn();
      let bindCount = 0;
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockImplementation(async () => {
          bindCount++;
          return bindCount >= 3;
        }),
        tryConnectAsClientAsync: vi.fn().mockResolvedValue(false),
        delay: vi.fn().mockResolvedValue(undefined),
      });
      const manager = new HandOffManager({ port: 38741, deps, logger });

      manager.onHostTransferNotice();
      await manager.onHostDisconnectedAsync();

      const retryEntries = logger.mock.calls
        .map((c: any[]) => c[0])
        .filter((e: HandOffLogEntry) => e.reason === 'retry');
      expect(retryEntries.length).toBe(2);
      expect(retryEntries[0].data?.attempt).toBe(0);
      expect(retryEntries[1].data?.attempt).toBe(1);
    });

    it('logs retries-exhausted when all attempts fail', async () => {
      const logger = vi.fn();
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockResolvedValue(false),
        tryConnectAsClientAsync: vi.fn().mockResolvedValue(false),
        delay: vi.fn().mockResolvedValue(undefined),
      });
      const manager = new HandOffManager({ port: 38741, deps, logger });

      manager.onHostTransferNotice();
      await expect(manager.onHostDisconnectedAsync()).rejects.toThrow(HostUnreachableError);

      const reasons = logger.mock.calls.map((c: any[]) => c[0].reason);
      expect(reasons).toContain('retries-exhausted');
    });

    it('does not throw when no logger is provided', async () => {
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockResolvedValue(true),
      });
      const manager = new HandOffManager({ port: 38741, deps });

      manager.onHostTransferNotice();
      const result = await manager.onHostDisconnectedAsync();

      expect(result).toBe('promoted');
    });

    it('includes ISO timestamp in every log entry', async () => {
      const logger = vi.fn();
      const deps = createMockDeps({
        tryBindAsync: vi.fn().mockResolvedValue(true),
      });
      const manager = new HandOffManager({ port: 38741, deps, logger });

      manager.onHostTransferNotice();
      await manager.onHostDisconnectedAsync();

      for (const call of logger.mock.calls) {
        const entry: HandOffLogEntry = call[0];
        expect(entry.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
      }
    });
  });
});

// ---------------------------------------------------------------------------
// Health endpoint: new fields (Task 1.10)
// ---------------------------------------------------------------------------

describe('Health endpoint observability fields', () => {
  it('includes hostUptime and lastFailoverAt in response', () => {
    const startTime = Date.now() - 10_000;
    const hostStartTime = Date.now() - 5_000;
    const lastFailoverAt = new Date(hostStartTime).toISOString();

    const handler = createHealthHandler(() => ({
      port: 38741,
      protocolVersion: 2,
      sessions: 3,
      startTime,
      hostStartTime,
      lastFailoverAt,
    }));

    // Simulate an HTTP response object
    let statusCode = 0;
    let body = '';
    const res = {
      writeHead(code: number, _hdrs: Record<string, string | number>) {
        statusCode = code;
      },
      end(data: string) {
        body = data;
      },
    } as any;

    handler({} as any, res);

    expect(statusCode).toBe(200);
    const parsed = JSON.parse(body);
    expect(parsed.status).toBe('ok');
    expect(typeof parsed.hostUptime).toBe('number');
    expect(parsed.hostUptime).toBeLessThanOrEqual(parsed.uptime);
    expect(parsed.lastFailoverAt).toBe(lastFailoverAt);
  });

  it('defaults hostUptime to uptime when hostStartTime is not provided', () => {
    const startTime = Date.now() - 10_000;

    const handler = createHealthHandler(() => ({
      port: 38741,
      protocolVersion: 2,
      sessions: 0,
      startTime,
    }));

    let body = '';
    const res = {
      writeHead() {},
      end(data: string) { body = data; },
    } as any;

    handler({} as any, res);

    const parsed = JSON.parse(body);
    // hostUptime should equal uptime when no separate hostStartTime
    expect(parsed.hostUptime).toBe(parsed.uptime);
    expect(parsed.lastFailoverAt).toBeNull();
  });
});
