import { describe, it, expect, vi } from 'vitest';
import { rgbaToPng } from '../../../encoders/index.js';
import {
  formatSheetHeader,
  recordViewportHandlerAsync,
  toManifest,
  toOutputFiles,
} from './record.js';

const PNG_SIGNATURE = [137, 80, 78, 71];
const PIXELS = Buffer.from([255, 0, 0, 255, 0, 0, 255, 255]);

function capturedFrame(t: number, frame: number, format: 'png' | 'rgba') {
  return {
    t,
    frame,
    width: 2,
    height: 1,
    format,
    data: (format === 'png' ? rgbaToPng(PIXELS, 2, 1) : PIXELS).toString(
      'base64'
    ),
  };
}

function createSession(
  overrides: Record<string, unknown> = {},
  context = 'edit',
  state = 'Edit'
) {
  return {
    context,
    info: { sessionId: `${context}-1`, instanceId: 'instance-1', state },
    recordViewportAsync: vi.fn().mockResolvedValue({
      frames: [
        capturedFrame(0.0004, 0, 'png'),
        capturedFrame(0.2, 6, 'rgba'),
        capturedFrame(0.4, 12, 'png'),
      ],
      skipped: [],
      requested: 20,
      frameCount: 20,
      elapsed: 0.6001234,
      truncated: false,
      clock: 'renderStep',
      ...overrides,
    }),
  } as any;
}

function signature(base64: string): number[] {
  return [...Buffer.from(base64, 'base64').subarray(0, 4)];
}

describe('recordViewportHandlerAsync', () => {
  it('keeps PNG frames, encodes raw ones, and reports the rate it got', async () => {
    const session = createSession();

    const result = await recordViewportHandlerAsync(session, {
      duration: 0.6,
      fps: 30,
      scale: 0.5,
    });

    expect(session.recordViewportAsync).toHaveBeenCalledWith({
      duration: 0.6,
      fps: 30,
      scale: 0.5,
    });
    expect(result.frames.map((f) => f.file)).toEqual([
      'frame-000.png',
      'frame-001.png',
      'frame-002.png',
    ]);
    for (const frame of result.frames) {
      expect(signature(frame.data)).toEqual(PNG_SIGNATURE);
    }
    expect(result.captured).toBe(3);
    expect(result.requested).toBe(20);
    expect(result.captureRate).toBeCloseTo(5, 1);
    expect(result.summary).toBe(
      'Captured 3 of 20 requested frames over 0.600s (5.0/s, --fps 30)'
    );
    expect(signature(result.sheet!)).toEqual(PNG_SIGNATURE);
  });

  it('reports captures it could not read', async () => {
    const skipped = [{ t: 0.1, frame: 3, reason: 'could not read' }];

    const result = await recordViewportHandlerAsync(
      createSession({ skipped }),
      { duration: 0.6 }
    );

    expect(result.skipped).toEqual(skipped);
    expect(result.summary).toContain('1 could not be read');
  });

  it('skips the sheet with --sheet-frames 0', async () => {
    const result = await recordViewportHandlerAsync(createSession(), {
      duration: 0.6,
      sheetFrames: 0,
    });

    expect(result.sheet).toBeUndefined();
    expect(toOutputFiles(result).map((f) => f.relativePath)).not.toContain(
      'sheet.png'
    );
  });

  it.each([-1, 1.5])(
    'refuses --sheet-frames %s before recording',
    async (sheetFrames) => {
      const session = createSession();

      await expect(
        recordViewportHandlerAsync(session, { duration: 1, sheetFrames })
      ).rejects.toThrow('--sheet-frames');
      expect(session.recordViewportAsync).not.toHaveBeenCalled();
    }
  );

  it.each([
    ['client', 'Play', "Can't record during a playtest"],
    ['server', 'Play', "Can't record during a playtest"],
    ['edit', 'Play', "Can't record during a playtest"],
    ['server', 'Run', "Can't record a Run-mode playtest"],
    ['edit', 'Run', "Can't record a Run-mode playtest"],
  ])('refuses a %s session in %s mode', async (context, state, message) => {
    const session = createSession({}, context, state);

    await expect(
      recordViewportHandlerAsync(session, { duration: 1 })
    ).rejects.toThrow(message);
    expect(session.recordViewportAsync).not.toHaveBeenCalled();
  });
});

describe('toManifest', () => {
  it('rounds times to milliseconds and leaves out pixel data', async () => {
    const result = await recordViewportHandlerAsync(createSession(), {
      duration: 0.6,
    });

    const manifest = toManifest(result) as any;

    expect(manifest.elapsed).toBe(0.6);
    expect(manifest.captureRate).toBe(
      Math.round(result.captureRate * 1000) / 1000
    );
    expect(manifest.captured).toBe(3);
    expect(manifest).not.toHaveProperty('frameCount');
    expect(manifest).not.toHaveProperty('skipped');
    expect(manifest.frames[0]).toEqual({
      index: 0,
      t: 0,
      frame: 0,
      file: 'frame-000.png',
      width: 2,
      height: 1,
    });
  });

  it('lists skipped captures when there are any', async () => {
    const result = await recordViewportHandlerAsync(
      createSession({ skipped: [{ t: 0.12345, frame: 3, reason: 'x' }] }),
      { duration: 0.6 }
    );

    expect((toManifest(result) as any).skipped).toEqual([
      { t: 0.123, frame: 3, reason: 'x' },
    ]);
  });
});

describe('toOutputFiles', () => {
  it('writes the frames, the sheet and the manifest', async () => {
    const result = await recordViewportHandlerAsync(createSession(), {
      duration: 0.6,
    });

    const files = toOutputFiles(result);

    expect(files.map((f) => f.relativePath)).toEqual([
      'frame-000.png',
      'frame-001.png',
      'frame-002.png',
      'sheet.png',
      'manifest.json',
    ]);
    expect(JSON.parse(files[4].data as string)).toEqual(toManifest(result));
  });
});

describe('formatSheetHeader', () => {
  it('says how many were captured, how fast and over how long', () => {
    expect(
      formatSheetHeader({
        captured: 6,
        requested: 19,
        skipped: 0,
        elapsed: 1.2013,
        captureRate: 4.98,
      })
    ).toBe('6 of 19 captured · 5.0/s · 1.201s');
  });

  it('adds skipped captures', () => {
    expect(
      formatSheetHeader({
        captured: 6,
        requested: 19,
        skipped: 2,
        elapsed: 1,
        captureRate: 5,
      })
    ).toBe('6 of 19 captured · 5.0/s · 1.000s · 2 skipped');
  });
});
