/**
 * Unit tests for the screenshot command handler.
 */

import { describe, it, expect, vi } from 'vitest';
import { captureScreenshotHandlerAsync } from './screenshot.js';
import { rgbaToPng } from './rgba-to-png.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockSession(screenshotResult: {
  data: string;
  format: 'png' | 'rgba';
  width: number;
  height: number;
}) {
  return {
    captureScreenshotAsync: vi.fn().mockResolvedValue(screenshotResult),
  } as any;
}

// ---------------------------------------------------------------------------
// rgbaToPng tests
// ---------------------------------------------------------------------------

describe('rgbaToPng', () => {
  it('produces a valid PNG for a 1x1 red pixel', () => {
    // 1x1 RGBA: red pixel (255, 0, 0, 255)
    const rgba = Buffer.from([255, 0, 0, 255]);
    const png = rgbaToPng(rgba, 1, 1);

    // Check PNG signature
    expect(png[0]).toBe(137);
    expect(png[1]).toBe(80); // 'P'
    expect(png[2]).toBe(78); // 'N'
    expect(png[3]).toBe(71); // 'G'
    expect(png.length).toBeGreaterThan(8);
  });

  it('produces a valid PNG for a 2x2 image', () => {
    // 2x2 RGBA: 4 pixels * 4 bytes = 16 bytes
    const rgba = Buffer.alloc(16, 0);
    // Set all pixels to blue (0, 0, 255, 255)
    for (let i = 0; i < 4; i++) {
      rgba[i * 4 + 2] = 255;
      rgba[i * 4 + 3] = 255;
    }
    const png = rgbaToPng(rgba, 2, 2);

    // Check PNG signature
    expect(png.subarray(0, 4)).toEqual(Buffer.from([137, 80, 78, 71]));
  });

  it('throws on data length mismatch', () => {
    const rgba = Buffer.alloc(10); // Wrong size for any dimensions
    expect(() => rgbaToPng(rgba, 2, 2)).toThrow('data length mismatch');
  });

  it('round-trips: PNG starts with signature and ends with IEND', () => {
    const rgba = Buffer.alloc(4 * 4 * 4, 128); // 4x4 gray pixels
    const png = rgbaToPng(rgba, 4, 4);

    // Signature
    expect(png.subarray(0, 8)).toEqual(
      Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    );

    // IEND chunk at end: length(0) + "IEND" + CRC
    const iendType = png.subarray(png.length - 8, png.length - 4).toString('ascii');
    expect(iendType).toBe('IEND');
  });
});

// ---------------------------------------------------------------------------
// captureScreenshotHandlerAsync tests
// ---------------------------------------------------------------------------

describe('captureScreenshotHandlerAsync', () => {
  it('returns screenshot result with summary (png format)', async () => {
    const session = createMockSession({
      data: 'iVBORw0KGgoAAAANSUhEUg==',
      format: 'png',
      width: 1920,
      height: 1080,
    });

    const result = await captureScreenshotHandlerAsync(session);

    expect(result.data).toBe('iVBORw0KGgoAAAANSUhEUg==');
    expect(result.width).toBe(1920);
    expect(result.height).toBe(1080);
    expect(result.summary).toBe('Screenshot captured (1920x1080)');
  });

  it('converts rgba format to png', async () => {
    // 1x1 red pixel as RGBA
    const rgbaBase64 = Buffer.from([255, 0, 0, 255]).toString('base64');
    const session = createMockSession({
      data: rgbaBase64,
      format: 'rgba',
      width: 1,
      height: 1,
    });

    const result = await captureScreenshotHandlerAsync(session);

    // Result should be valid PNG base64
    const pngBuffer = Buffer.from(result.data, 'base64');
    expect(pngBuffer[0]).toBe(137); // PNG signature
    expect(pngBuffer[1]).toBe(80);
    expect(result.width).toBe(1);
    expect(result.height).toBe(1);
    expect(result.summary).toBe('Screenshot captured (1x1)');
  });

  it('calls session.captureScreenshotAsync', async () => {
    const session = createMockSession({
      data: 'base64data',
      format: 'png',
      width: 800,
      height: 600,
    });

    await captureScreenshotHandlerAsync(session);

    expect(session.captureScreenshotAsync).toHaveBeenCalledOnce();
  });

  it('handles different dimensions', async () => {
    const session = createMockSession({
      data: 'abc',
      format: 'png',
      width: 3840,
      height: 2160,
    });

    const result = await captureScreenshotHandlerAsync(session);

    expect(result.width).toBe(3840);
    expect(result.height).toBe(2160);
    expect(result.summary).toContain('3840x2160');
  });

  it('propagates errors from session', async () => {
    const session = {
      captureScreenshotAsync: vi.fn().mockRejectedValue(new Error('Screenshot failed')),
    } as any;

    await expect(captureScreenshotHandlerAsync(session)).rejects.toThrow('Screenshot failed');
  });

  it('handles missing fields gracefully', async () => {
    const session = {
      captureScreenshotAsync: vi.fn().mockResolvedValue({
        data: undefined,
        format: 'png',
        width: undefined,
        height: undefined,
      }),
    } as any;

    const result = await captureScreenshotHandlerAsync(session);

    expect(result.data).toBe('');
    expect(result.width).toBe(0);
    expect(result.height).toBe(0);
    expect(result.summary).toBe('Screenshot captured (0x0)');
  });

  it('passes options without affecting capture', async () => {
    const session = createMockSession({
      data: 'base64data',
      format: 'png',
      width: 1280,
      height: 720,
    });

    const result = await captureScreenshotHandlerAsync(session, {
      output: '/tmp/screenshot.png',
      base64: true,
    });

    expect(result.data).toBe('base64data');
    expect(session.captureScreenshotAsync).toHaveBeenCalledOnce();
  });
});
