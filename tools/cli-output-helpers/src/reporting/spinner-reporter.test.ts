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
  const realWrite = process.stdout.write.bind(process.stdout);
  vi.spyOn(process.stdout, 'write').mockImplementation(
    ((chunk: any, ...args: any[]) => {
      writes.push(typeof chunk === 'string' ? chunk : chunk.toString());
      return true;
    }) as any
  );

  // Suppress console.log (used by startAsync header)
  vi.spyOn(console, 'log').mockImplementation(() => {});

  return { state, spinner, writes, realWrite };
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

describe('SpinnerReporter stdout resilience', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('cursor-up matches rendered line count with no external writes', async () => {
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

  it('accounts for single external stdout write between renders', async () => {
    const { state, spinner, writes } = setup();

    state.onPackageStart('pkg-a');
    await spinner.startAsync();

    // Simulate an external write between renders
    process.stdout.write('external log\n');

    writes.length = 0;
    vi.advanceTimersByTime(80);

    // Should be 3 (rendered) + 1 (external) = 4
    const ups = extractCursorUps(writes);
    expect(ups.length).toBe(1);
    expect(ups[0]).toBe(4);

    await spinner.stopAsync();
  });

  it('accounts for multiple external stdout writes', async () => {
    const { state, spinner, writes } = setup();

    state.onPackageStart('pkg-a');
    await spinner.startAsync();

    // 3 external lines
    process.stdout.write('line1\n');
    process.stdout.write('line2\nline3\n');

    writes.length = 0;
    vi.advanceTimersByTime(80);

    // Should be 3 (rendered) + 3 (external) = 6
    const ups = extractCursorUps(writes);
    expect(ups.length).toBe(1);
    expect(ups[0]).toBe(6);

    await spinner.stopAsync();
  });

  it('resets extra line count after each render', async () => {
    const { state, spinner, writes } = setup();

    state.onPackageStart('pkg-a');
    await spinner.startAsync();

    // External write before render 2
    process.stdout.write('noise\n');
    vi.advanceTimersByTime(80);

    // No external write before render 3
    writes.length = 0;
    vi.advanceTimersByTime(80);

    // Render 3 should only cursor-up by renderedLineCount (3), no extras
    const ups = extractCursorUps(writes);
    expect(ups.length).toBe(1);
    expect(ups[0]).toBe(3);

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
