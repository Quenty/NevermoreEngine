/**
 * Unit tests for the screenshot command handler.
 */

import { describe, it, expect, vi } from 'vitest';
import { captureScreenshotHandlerAsync } from './screenshot.js';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function createMockSession(screenshotResult: {
  data: string;
  format: 'png';
  width: number;
  height: number;
}) {
  return {
    captureScreenshotAsync: vi.fn().mockResolvedValue(screenshotResult),
  } as any;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('captureScreenshotHandlerAsync', () => {
  it('returns screenshot result with summary', async () => {
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
