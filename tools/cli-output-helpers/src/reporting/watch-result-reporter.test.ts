import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { WatchResultReporter } from './watch-result-reporter.js';

describe('WatchResultReporter', () => {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let writeSpy: any;
  const originalIsTTY = process.stdout.isTTY;

  beforeEach(() => {
    writeSpy = vi.spyOn(process.stdout, 'write').mockImplementation(() => true);
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    writeSpy.mockRestore();
    process.stdout.isTTY = originalIsTTY;
  });

  it('starts the renderer on the first onResult and updates on subsequent calls', () => {
    process.stdout.isTTY = false;
    const renderFn = vi.fn((r: { v: number }) => `v=${r.v}`);
    const reporter = new WatchResultReporter<{ v: number }>({
      render: renderFn,
      intervalMs: 1000,
    });

    reporter.onResult({ v: 1 });
    expect(renderFn).toHaveBeenCalledWith({ v: 1 });
    expect(writeSpy).toHaveBeenCalled();

    reporter.onResult({ v: 2 });
    expect(renderFn).toHaveBeenCalledWith({ v: 2 });
  });

  it('stopAsync without any onResult does not start the renderer', async () => {
    process.stdout.isTTY = false;
    const renderFn = vi.fn(() => '');
    const reporter = new WatchResultReporter<unknown>({ render: renderFn });

    await reporter.stopAsync();
    expect(renderFn).not.toHaveBeenCalled();
  });
});
