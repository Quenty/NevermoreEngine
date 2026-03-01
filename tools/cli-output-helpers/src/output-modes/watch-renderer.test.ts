import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { createWatchRenderer } from './watch-renderer.js';

describe('createWatchRenderer', () => {
  let writes: string[];

  beforeEach(() => {
    vi.useFakeTimers();
    writes = [];
    vi.spyOn(process.stdout, 'write').mockImplementation(((chunk: any) => {
      writes.push(typeof chunk === 'string' ? chunk : chunk.toString());
      return true;
    }) as any);
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('start renders immediately and stop clears interval with final render', () => {
    let count = 0;
    const renderer = createWatchRenderer(() => `frame-${count++}`, {
      rewrite: false,
      intervalMs: 1000,
    });

    renderer.start();
    expect(writes).toEqual(['frame-0\n']);

    renderer.stop();
    // stop does a final render
    expect(writes).toEqual(['frame-0\n', 'frame-1\n']);

    // After stop, no more renders should happen
    writes.length = 0;
    vi.advanceTimersByTime(3000);
    expect(writes).toEqual([]);
  });

  it('update forces immediate render and resets interval', () => {
    let count = 0;
    const renderer = createWatchRenderer(() => `frame-${count++}`, {
      rewrite: false,
      intervalMs: 1000,
    });

    renderer.start(); // frame-0
    expect(writes).toEqual(['frame-0\n']);

    // Advance 500ms, then force update
    vi.advanceTimersByTime(500);
    renderer.update(); // frame-1 (forced)
    expect(writes).toEqual(['frame-0\n', 'frame-1\n']);

    // Advance 500ms more — the old interval would have fired at 1000ms total,
    // but update() reset it, so nothing fires yet
    vi.advanceTimersByTime(500);
    expect(writes).toEqual(['frame-0\n', 'frame-1\n']);

    // Advance another 500ms (1000ms since update), new interval fires
    vi.advanceTimersByTime(500);
    expect(writes).toEqual(['frame-0\n', 'frame-1\n', 'frame-2\n']);

    renderer.stop();
  });

  it('non-TTY mode only writes when content changes', () => {
    let value = 'same';
    const renderer = createWatchRenderer(() => value, {
      rewrite: false,
      intervalMs: 100,
    });

    renderer.start(); // writes "same"
    expect(writes).toEqual(['same\n']);

    // Same content on next interval — should NOT write
    vi.advanceTimersByTime(100);
    expect(writes).toEqual(['same\n']);

    // Change content — should write
    value = 'different';
    vi.advanceTimersByTime(100);
    expect(writes).toEqual(['same\n', 'different\n']);

    renderer.stop();
  });

  it('stop clears the interval so no more renders happen', () => {
    let count = 0;
    const renderer = createWatchRenderer(() => `f-${count++}`, {
      rewrite: false,
      intervalMs: 100,
    });

    renderer.start(); // f-0
    renderer.stop();  // f-1 (final)

    writes.length = 0;
    vi.advanceTimersByTime(1000);
    expect(writes).toEqual([]);
  });

  it('TTY rewrite mode hides/shows cursor and uses escape codes', () => {
    let count = 0;
    const renderer = createWatchRenderer(() => `line-${count++}`, {
      rewrite: true,
      intervalMs: 100,
    });

    renderer.start();
    // Should have written hide-cursor + first frame
    expect(writes[0]).toBe('\x1b[?25l');
    expect(writes[1]).toBe('line-0\n');

    // Advance to trigger second render — should include cursor-up + clear
    vi.advanceTimersByTime(100);
    const cursorUpWrite = writes.find((w) => w.includes('\x1b[1A\x1b[J'));
    expect(cursorUpWrite).toBeDefined();

    renderer.stop();
    // Should have written show-cursor
    const lastWrite = writes[writes.length - 1];
    expect(lastWrite).toBe('\x1b[?25h');
  });
});
