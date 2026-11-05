import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  getStudioMcpSnapshotAsync,
  resetStudioMcpSnapshot,
} from './studio-mcp-snapshot.js';
import type { StudioMcpResult, StudioMcpTarget } from './roblox-studio-mcp.js';

type ListResult = StudioMcpResult<StudioMcpTarget[]>;

const OK: ListResult = {
  success: true,
  value: [{ studioId: 'mcp-1', placeName: 'Place1' }],
};

describe('getStudioMcpSnapshotAsync', () => {
  beforeEach(() => resetStudioMcpSnapshot());
  afterEach(() => vi.useRealTimers());

  it('waits for the first check and reports the Studios it found', async () => {
    const listAsync = vi.fn(async () => OK);

    const snapshot = await getStudioMcpSnapshotAsync({ listAsync });

    expect(snapshot).toMatchObject({
      status: 'ok',
      studios: [{ studioId: 'mcp-1' }],
    });
    expect(listAsync).toHaveBeenCalledWith(
      expect.objectContaining({ readPlaceIds: false, timeoutMs: 3000 })
    );
  });

  it('reuses a fresh snapshot without checking again', async () => {
    const listAsync = vi.fn(async () => OK);

    await getStudioMcpSnapshotAsync({ listAsync });
    await getStudioMcpSnapshotAsync({ listAsync });

    expect(listAsync).toHaveBeenCalledTimes(1);
  });

  it('answers with the stale snapshot at once and refreshes in the background', async () => {
    let resolveSecond: (result: ListResult) => void = () => {};
    const listAsync = vi
      .fn<() => Promise<ListResult>>()
      .mockResolvedValueOnce(OK)
      .mockImplementationOnce(
        () => new Promise((resolve) => (resolveSecond = resolve))
      );

    const first = await getStudioMcpSnapshotAsync({ listAsync, maxAgeMs: 0 });
    const second = await getStudioMcpSnapshotAsync({ listAsync, maxAgeMs: 0 });

    expect(second).toBe(first);
    expect(listAsync).toHaveBeenCalledTimes(2);
    resolveSecond({ success: false, reason: 'timeout', message: 'slow' });
    await new Promise((resolve) => setImmediate(resolve));
    const third = await getStudioMcpSnapshotAsync({ listAsync });
    expect(third).toMatchObject({
      status: 'timeout',
      message: 'slow',
      lastOkAt: first?.checkedAt,
    });
  });

  it('runs one check at a time', async () => {
    const listAsync = vi.fn(
      () =>
        new Promise<ListResult>((resolve) => setTimeout(() => resolve(OK), 20))
    );

    await Promise.all([
      getStudioMcpSnapshotAsync({ listAsync }),
      getStudioMcpSnapshotAsync({ listAsync }),
    ]);

    expect(listAsync).toHaveBeenCalledTimes(1);
  });

  it('gives up waiting rather than hang when the first check does not finish', async () => {
    const listAsync = vi.fn(() => new Promise<ListResult>(() => {}));

    const started = Date.now();
    const snapshot = await getStudioMcpSnapshotAsync({
      listAsync,
      maxWaitMs: 20,
    });

    expect(snapshot).toBeUndefined();
    expect(Date.now() - started).toBeLessThan(1000);
  });

  it('records a failure with its reason', async () => {
    const listAsync = vi.fn(
      async (): Promise<ListResult> => ({
        success: false,
        reason: 'unavailable',
        message: 'not installed',
      })
    );

    expect(await getStudioMcpSnapshotAsync({ listAsync })).toMatchObject({
      status: 'unavailable',
      message: 'not installed',
      studios: [],
    });
  });
});
