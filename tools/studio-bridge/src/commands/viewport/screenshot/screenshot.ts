/**
 * `viewport screenshot` — capture a viewport screenshot from a
 * connected Studio session.
 */

import { defineCommand } from '../../framework/define-command.js';
import type { BridgeSession } from '../../../bridge/index.js';
import type { ScreenshotResult as BridgeScreenshotResult } from '../../../bridge/index.js';
import { rgbaToPng } from '../../rgba-to-png.js';
import { formatAsJson } from '../../../cli/format-output.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ScreenshotResult {
  data: string;
  width: number;
  height: number;
  summary: string;
}

export interface ScreenshotOptions {
  output?: string;
  base64?: boolean;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

export async function captureScreenshotHandlerAsync(
  session: BridgeSession,
  _options: ScreenshotOptions = {},
): Promise<ScreenshotResult> {
  const result: BridgeScreenshotResult =
    await session.captureScreenshotAsync();

  let pngBase64: string;
  if (result.format === 'rgba') {
    const rgbaBuffer = Buffer.from(result.data, 'base64');
    const pngBuffer = rgbaToPng(rgbaBuffer, result.width, result.height);
    pngBase64 = pngBuffer.toString('base64');
  } else {
    pngBase64 = result.data ?? '';
  }

  return {
    data: pngBase64,
    width: result.width ?? 0,
    height: result.height ?? 0,
    summary: `Screenshot captured (${result.width ?? 0}x${result.height ?? 0})`,
  };
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const screenshotCommand = defineCommand<ScreenshotOptions, ScreenshotResult>({
  group: 'viewport',
  name: 'screenshot',
  description: 'Capture a viewport screenshot from Studio',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {},
  cli: {
    binaryField: 'data',
    formatResult: {
      text: (result) => result.summary,
      table: (result) => result.summary,
      json: (result) => formatAsJson({ width: result.width, height: result.height, summary: result.summary }),
    },
  },
  handler: async (session) => captureScreenshotHandlerAsync(session),
  mcp: {
    mapResult: (result) => {
      if (result.data) {
        return [
          {
            type: 'image' as const,
            data: result.data,
            mimeType: 'image/png',
          },
        ];
      }
      return [
        {
          type: 'text' as const,
          text: JSON.stringify({
            width: result.width,
            height: result.height,
            summary: result.summary,
          }),
        },
      ];
    },
  },
});
