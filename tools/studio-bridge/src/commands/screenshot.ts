/**
 * Handler for the `screenshot` command. Captures a viewport screenshot
 * from a connected Studio session.
 */

import type { BridgeSession } from '../bridge/index.js';
import type { ScreenshotResult as BridgeScreenshotResult } from '../bridge/index.js';
import { rgbaToPng } from './rgba-to-png.js';

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

/**
 * Capture a viewport screenshot from a connected Studio session.
 */
export async function captureScreenshotHandlerAsync(
  session: BridgeSession,
  _options: ScreenshotOptions = {},
): Promise<ScreenshotResult> {
  const result: BridgeScreenshotResult = await session.captureScreenshotAsync();

  let pngBase64: string;
  if (result.format === 'rgba') {
    // Plugin sent raw RGBA pixels — convert to PNG
    const rgbaBuffer = Buffer.from(result.data, 'base64');
    const pngBuffer = rgbaToPng(rgbaBuffer, result.width, result.height);
    pngBase64 = pngBuffer.toString('base64');
  } else {
    // Already PNG
    pngBase64 = result.data ?? '';
  }

  return {
    data: pngBase64,
    width: result.width ?? 0,
    height: result.height ?? 0,
    summary: `Screenshot captured (${result.width ?? 0}x${result.height ?? 0})`,
  };
}
