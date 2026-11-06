import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { describe, it, expect } from 'vitest';
import { parseDurationSeconds, tryParseDurationSeconds } from './duration.js';
import { DEFAULT_MAX_FRAMES, resolveRecordingAsync } from './recording-args.js';

describe('tryParseDurationSeconds', () => {
  it.each([
    ['800ms', 0.8],
    ['0.8s', 0.8],
    ['2s', 2],
    ['5m', 300],
    ['1d', 86400],
  ])('reads %s', (value, seconds) => {
    expect(tryParseDurationSeconds(value)).toBeCloseTo(seconds);
  });

  it('needs a unit', () => {
    expect(tryParseDurationSeconds('2')).toBeUndefined();
  });
});

describe('parseDurationSeconds', () => {
  it('reads a bare number as seconds', () => {
    expect(parseDurationSeconds('1.5', '--duration')).toBe(1.5);
  });

  it('names the flag when it cannot read the value', () => {
    expect(() => parseDurationSeconds('soon', '--duration')).toThrow(
      "Can't read --duration 'soon'"
    );
  });
});

describe('resolveRecordingAsync', () => {
  it('parses the duration and fills in the frame cap', async () => {
    expect(
      await resolveRecordingAsync({ duration: '600ms', trigger: 'go()' })
    ).toEqual({
      trigger: 'go()',
      duration: 0.6,
      maxFrames: DEFAULT_MAX_FRAMES,
    });
  });

  it('reads the trigger from a file', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'recording-args-'));
    const file = path.join(dir, 'trigger.lua');
    fs.writeFileSync(file, 'print("go")');

    const payload = await resolveRecordingAsync({
      duration: '1',
      triggerFile: file,
      fps: 30,
    });

    expect(payload.trigger).toBe('print("go")');
    expect(payload.fps).toBe(30);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('needs a duration', async () => {
    await expect(resolveRecordingAsync({})).rejects.toThrow('--duration');
  });

  it('refuses both --trigger and --trigger-file', async () => {
    await expect(
      resolveRecordingAsync({ duration: '1s', trigger: 'a', triggerFile: 'b' })
    ).rejects.toThrow('not both');
  });

  it('refuses a non-positive fps', async () => {
    await expect(
      resolveRecordingAsync({ duration: '1s', fps: 0 })
    ).rejects.toThrow('--fps');
  });
});
