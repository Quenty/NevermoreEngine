import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest';
import { SpinnerReporter } from './spinner-reporter.js';
import { LiveStateTracker } from './state/live-state-tracker.js';

/**
 * Creates a spinner + state tracker for 1 package in the "building" phase.
 * Returns helpers to inspect what was written to stdout.
 */
function setup() {
  const state = new LiveStateTracker(['pkg-a']);
  const spinner = new SpinnerReporter(state, { showLogs: false });

  // Capture everything written to stdout
  const writes: string[] = [];
  vi.spyOn(process.stdout, 'write').mockImplementation(((
    chunk: any,
    ..._args: any[]
  ) => {
    writes.push(typeof chunk === 'string' ? chunk : chunk.toString());
    return true;
  }) as any);

  // Suppress console.log (used by startAsync header)
  vi.spyOn(console, 'log').mockImplementation(() => {});

  return { state, spinner, writes };
}

/** Extract cursor-up escape codes (\x1b[NA) from captured writes. */
function extractCursorUps(writes: string[]): number[] {
  const results: number[] = [];
  for (const w of writes) {
    const matches = w.matchAll(/\x1b\[(\d+)A/g);
    for (const m of matches) {
      results.push(Number(m[1]));
    }
  }
  return results;
}

describe('SpinnerReporter cursor math', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('cursor-up matches rendered line count', async () => {
    const { state, spinner, writes } = setup();

    state.onPackageStart('pkg-a');
    await spinner.startAsync();

    // First render happened in startAsync — no cursor-up (nothing to erase yet).
    // Advance timer to trigger a second render.
    writes.length = 0;
    vi.advanceTimersByTime(80);

    // Second render should cursor-up by the number of lines from render 1.
    // Lines: 1 package line + 1 blank + 1 counter = 3
    const ups = extractCursorUps(writes);
    expect(ups.length).toBe(1);
    expect(ups[0]).toBe(3);

    await spinner.stopAsync();
  });

  it('cursor-up ignores external writes (they are captured, not emitted)', async () => {
    const { state, spinner, writes } = setup();

    state.onPackageStart('pkg-a');
    await spinner.startAsync();

    // External writes during the spinner are buffered, not sent to the terminal.
    process.stdout.write('external log\n');
    process.stdout.write('more\nstuff\n');

    writes.length = 0;
    vi.advanceTimersByTime(80);

    // Still just 3 — external writes never actually reach stdout, so they
    // can't shift the cursor.
    const ups = extractCursorUps(writes);
    expect(ups.length).toBe(1);
    expect(ups[0]).toBe(3);

    await spinner.stopAsync();
  });
});

describe('SpinnerReporter output capture', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('captures writes during the run and flushes them on stop', async () => {
    const { state, spinner, writes } = setup();

    state.onPackageStart('pkg-a');
    await spinner.startAsync();

    // Capture index where post-spinner output begins.
    process.stdout.write('hello\n');
    process.stdout.write('world\n');

    // Verify nothing was emitted live (only spinner frames so far).
    expect(writes.join('')).not.toContain('hello');
    expect(writes.join('')).not.toContain('world');

    await spinner.stopAsync();

    // After stopAsync, the captured output must have been flushed.
    const all = writes.join('');
    expect(all).toContain('hello');
    expect(all).toContain('world');
    // Order is preserved
    expect(all.indexOf('hello')).toBeLessThan(all.indexOf('world'));
  });

  it('captures stderr writes too', async () => {
    const { state, spinner, writes } = setup();
    // Intercept stderr the same way stdout is mocked.
    vi.spyOn(process.stderr, 'write').mockImplementation(((
      chunk: any,
      ..._args: any[]
    ) => {
      writes.push(typeof chunk === 'string' ? chunk : chunk.toString());
      return true;
    }) as any);

    state.onPackageStart('pkg-a');
    await spinner.startAsync();

    process.stderr.write('err line\n');

    expect(writes.join('')).not.toContain('err line');

    await spinner.stopAsync();

    expect(writes.join('')).toContain('err line');
  });

  it('invokes the Node-style completion callback on captured writes', async () => {
    const { state, spinner } = setup();

    state.onPackageStart('pkg-a');
    await spinner.startAsync();

    const cb = vi.fn();
    process.stdout.write('payload\n', cb);

    expect(cb).toHaveBeenCalledTimes(1);

    await spinner.stopAsync();
  });

  it('restores process.stdout.write on stop', async () => {
    const { state, spinner } = setup();

    state.onPackageStart('pkg-a');
    await spinner.startAsync();

    // During the spinner, stdout.write is the interceptor
    const interceptor = process.stdout.write;

    await spinner.stopAsync();

    // After stop, stdout.write should no longer be the interceptor
    expect(process.stdout.write).not.toBe(interceptor);
    // And it should still be callable
    expect(typeof process.stdout.write).toBe('function');
  });
});
