/**
 * Unit tests for the screenshot command handler.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { captureScreenshotHandlerAsync } from './screenshot.js';
import { pngToRgba, rgbaToPng } from '../../../encoders/index.js';

vi.mock('../../../roblox-mcp/index.js', () => ({
  tryCaptureStudioScreenAsync: vi.fn(),
}));
vi.mock('../../shared/studio-mcp-target.js', () => ({
  resolveStudioMcpTargetAsync: vi.fn(async () => ({ target: 'instance-1' })),
}));

import { tryCaptureStudioScreenAsync } from '../../../roblox-mcp/index.js';

const EDIT_INFO = {
  sessionId: 'edit-1',
  instanceId: 'instance-1',
  state: 'Edit',
};

function playtestSession(context: string, state = 'Play') {
  return {
    context,
    info: { sessionId: `${context}-1`, instanceId: 'instance-1', state },
    captureScreenshotAsync: vi.fn(),
  } as any;
}

function mcpImage(width: number, height: number) {
  const rgba = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    rgba.set([i % width, 0, 0, 255], i * 4);
  }
  return {
    success: true as const,
    value: { data: rgbaToPng(rgba, width, height), mimeType: 'image/png' },
  };
}

function createMockSession(screenshotResult: {
  data: string;
  format: 'png' | 'rgba';
  width: number;
  height: number;
}) {
  return {
    context: 'edit',
    info: EDIT_INFO,
    captureScreenshotAsync: vi.fn().mockResolvedValue(screenshotResult),
  } as any;
}

describe('captureScreenshotHandlerAsync', () => {
  beforeEach(() => {
    vi.mocked(tryCaptureStudioScreenAsync).mockReset();
  });

  it.each(['client', 'server', 'edit'])(
    'captures a Play-mode %s session through Studio MCP',
    async (context) => {
      vi.mocked(tryCaptureStudioScreenAsync).mockResolvedValue(mcpImage(4, 2));
      const session = playtestSession(context);

      const result = await captureScreenshotHandlerAsync(session);

      expect(session.captureScreenshotAsync).not.toHaveBeenCalled();
      expect(tryCaptureStudioScreenAsync).toHaveBeenCalledWith({
        target: 'instance-1',
      });
      expect(result).toMatchObject({
        width: 4,
        height: 2,
        source: 'studioMcp',
        summary: "Screenshot captured (4x2) through Studio's MCP server",
      });
      expect(pngToRgba(Buffer.from(result.data, 'base64')).width).toBe(4);
    }
  );

  it('reads the playtest state from the connection', async () => {
    vi.mocked(tryCaptureStudioScreenAsync).mockResolvedValue(mcpImage(2, 2));
    const session = playtestSession('edit', 'Edit');
    const connection = {
      listSessions: () => [{ ...session.info, state: 'Play' }],
    } as any;

    const result = await captureScreenshotHandlerAsync(session, {}, connection);

    expect(result.source).toBe('studioMcp');
  });

  it('crops and scales an MCP capture', async () => {
    vi.mocked(tryCaptureStudioScreenAsync).mockResolvedValue(mcpImage(8, 4));

    const result = await captureScreenshotHandlerAsync(
      playtestSession('client'),
      { region: [2, 0, 4, 4], scale: 0.5 }
    );

    expect([result.width, result.height]).toEqual([2, 2]);
    const { rgba } = pngToRgba(Buffer.from(result.data, 'base64'));
    expect(rgba[0]).toBe(2);
  });

  it('says why when Studio MCP cannot capture', async () => {
    vi.mocked(tryCaptureStudioScreenAsync).mockResolvedValue({
      success: false,
      reason: 'unavailable',
      message: "Studio's MCP server is unavailable: not found",
    });

    await expect(
      captureScreenshotHandlerAsync(playtestSession('client'))
    ).rejects.toMatchObject({
      code: 'CAPTURE_FAILED',
      message:
        "Studio's MCP server couldn't capture the playtest, and nothing else can.",
      cause: "Studio's MCP server is unavailable: not found",
    });
  });

  it.each(['server', 'edit'])(
    'refuses a Run-mode %s session up front',
    async (context) => {
      const session = playtestSession(context, 'Run');

      await expect(captureScreenshotHandlerAsync(session)).rejects.toThrow(
        "Can't capture a Run-mode playtest"
      );
      expect(tryCaptureStudioScreenAsync).not.toHaveBeenCalled();
      expect(session.captureScreenshotAsync).not.toHaveBeenCalled();
    }
  );

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
    expect(result.source).toBe('captureService');
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
      context: 'edit',
      info: EDIT_INFO,
      captureScreenshotAsync: vi
        .fn()
        .mockRejectedValue(new Error('Screenshot failed')),
    } as any;

    await expect(captureScreenshotHandlerAsync(session)).rejects.toThrow(
      'Screenshot failed'
    );
  });

  it('rejects data that is not a base64 string', async () => {
    const session = {
      context: 'edit',
      info: EDIT_INFO,
      captureScreenshotAsync: vi.fn().mockResolvedValue({
        data: { m: null, t: 'buffer', zbase64: 'KLUv' },
        format: 'png',
        width: 1,
        height: 1,
      }),
    } as any;

    await expect(captureScreenshotHandlerAsync(session)).rejects.toThrow(
      'The plugin sent screenshot data as object, not a base64 string'
    );
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
    });

    expect(result.data).toBe('base64data');
    expect(session.captureScreenshotAsync).toHaveBeenCalledOnce();
  });

  it('asks Studio to crop and scale', async () => {
    const session = createMockSession({
      data: 'base64data',
      format: 'png',
      width: 320,
      height: 180,
    });

    await captureScreenshotHandlerAsync(session, {
      region: [0, 0, 640, 360],
      scale: 0.5,
    });

    expect(session.captureScreenshotAsync).toHaveBeenCalledWith({
      region: [0, 0, 640, 360],
      scale: 0.5,
    });
  });
});
