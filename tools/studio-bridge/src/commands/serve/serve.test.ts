/**
 * Unit tests for the serve command handler.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { EventEmitter } from 'events';

// Mock BridgeConnection before importing serve handler
vi.mock('../../bridge/index.js', () => {
  return {
    BridgeConnection: {
      connectAsync: vi.fn(),
    },
  };
});

import { BridgeConnection } from '../../bridge/index.js';
import { serveHandlerAsync } from './serve.js';

function createMockConnection(
  port: number,
  role: 'host' | 'client' = 'host'
): EventEmitter & {
  disconnectAsync: ReturnType<typeof vi.fn>;
  port: number;
  role: 'host' | 'client';
} {
  const emitter = new EventEmitter();
  return Object.assign(emitter, {
    disconnectAsync: vi.fn().mockResolvedValue(undefined),
    port,
    role,
  });
}

describe('serveHandlerAsync', () => {
  let mockConnection: ReturnType<typeof createMockConnection>;
  const connectAsyncMock = BridgeConnection.connectAsync as ReturnType<
    typeof vi.fn
  >;

  beforeEach(() => {
    mockConnection = createMockConnection(38741);
    connectAsyncMock.mockResolvedValue(mockConnection);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('calls connectAsync with keepAlive true and correct port', async () => {
    const promise = serveHandlerAsync({ port: 38741, timeout: 10 });
    await promise;

    expect(connectAsyncMock).toHaveBeenCalledWith({
      port: 38741,
      keepAlive: true,
    });
  });

  it('uses default port 38741 when none specified', async () => {
    const promise = serveHandlerAsync({ timeout: 10 });
    await promise;

    expect(connectAsyncMock).toHaveBeenCalledWith({
      port: 38741,
      keepAlive: true,
    });
  });

  it('passes custom port through', async () => {
    mockConnection = createMockConnection(9999);
    connectAsyncMock.mockResolvedValue(mockConnection);

    const promise = serveHandlerAsync({ port: 9999, timeout: 10 });
    await promise;

    expect(connectAsyncMock).toHaveBeenCalledWith({
      port: 9999,
      keepAlive: true,
    });
  });

  it('throws clear error on EADDRINUSE', async () => {
    const err = new Error('listen EADDRINUSE: address already in use');
    (err as NodeJS.ErrnoException).code = 'EADDRINUSE';
    connectAsyncMock.mockRejectedValue(err);

    await expect(serveHandlerAsync({ port: 38741 })).rejects.toThrow(
      'Port 38741 is already in use'
    );
  });

  it('exits instead of lingering as a client when a host already runs', async () => {
    mockConnection = createMockConnection(38741, 'client');
    connectAsyncMock.mockResolvedValue(mockConnection);

    await expect(serveHandlerAsync({ port: 38741 })).rejects.toThrow(
      'Port 38741 is already in use'
    );
    expect(mockConnection.disconnectAsync).toHaveBeenCalled();
  });

  it('re-throws non-EADDRINUSE errors', async () => {
    connectAsyncMock.mockRejectedValue(new Error('some other error'));

    await expect(serveHandlerAsync({ port: 38741 })).rejects.toThrow(
      'some other error'
    );
  });

  it('disconnects after timeout expires', async () => {
    const result = await serveHandlerAsync({ timeout: 10 });

    expect(mockConnection.disconnectAsync).toHaveBeenCalled();
    expect(result).toMatchObject({ port: 38741, event: 'stopped' });
  });

  it('logs JSON startup when json option is set', async () => {
    const consoleSpy = vi.spyOn(console, 'log').mockImplementation(() => {});

    await serveHandlerAsync({ json: true, timeout: 10 });

    const startedCall = consoleSpy.mock.calls.find((call) => {
      try {
        const parsed = JSON.parse(call[0] as string);
        return parsed.event === 'started';
      } catch {
        return false;
      }
    });

    expect(startedCall).toBeDefined();
    const parsed = JSON.parse(startedCall![0] as string);
    expect(parsed.event).toBe('started');
    expect(parsed.port).toBe(38741);

    consoleSpy.mockRestore();
  });

  it('logs human-readable startup when json option is not set', async () => {
    const consoleSpy = vi.spyOn(console, 'log').mockImplementation(() => {});

    await serveHandlerAsync({ timeout: 10 });

    const startedCall = consoleSpy.mock.calls.find((call) =>
      (call[0] as string).includes('Bridge host listening')
    );

    expect(startedCall).toBeDefined();

    consoleSpy.mockRestore();
  });
});
