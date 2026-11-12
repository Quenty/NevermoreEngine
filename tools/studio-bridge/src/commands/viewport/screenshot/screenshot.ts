/**
 * `viewport screenshot` — capture a viewport screenshot from a
 * connected Studio session.
 */

import { defineCommand } from '../../framework/define-command.js';
import type { BridgeConnection, BridgeSession } from '../../../bridge/index.js';
import type { ScreenshotResult as BridgeScreenshotResult } from '../../../bridge/index.js';
import { rgbaToPng } from '../../../encoders/index.js';
import { formatJson } from '@quenty/cli-output-helpers/reporting';
import type { ViewportReadOptions } from '../../../server/web-socket-protocol.js';
import {
  resolveCaptureSource,
  toViewportReadOptions,
  viewportArgs,
  type CaptureSource,
  type ViewportArgs,
} from '../viewport-args.js';
import { captureThroughStudioMcpAsync } from './studio-mcp-screenshot.js';

export interface ScreenshotResult {
  data: string;
  width: number;
  height: number;
  source: CaptureSource;
  summary: string;
}

export interface ScreenshotOptions extends ViewportReadOptions {
  output?: string;
}

export async function captureScreenshotHandlerAsync(
  session: BridgeSession,
  options: ScreenshotOptions = {},
  connection?: BridgeConnection
): Promise<ScreenshotResult> {
  const { region, scale } = options;
  const readOptions: ViewportReadOptions = {
    ...(region ? { region } : {}),
    ...(scale !== undefined ? { scale } : {}),
  };

  if (resolveCaptureSource(session, connection) === 'studioMcp') {
    const shot = await captureThroughStudioMcpAsync(
      session,
      connection,
      readOptions
    );
    return {
      data: shot.png.toString('base64'),
      width: shot.width,
      height: shot.height,
      source: 'studioMcp',
      summary: `Screenshot captured (${shot.width}x${shot.height}) through Studio's MCP server`,
    };
  }

  const result: BridgeScreenshotResult = await session.captureScreenshotAsync(
    readOptions
  );
  if (typeof result.data !== 'string') {
    throw new Error(
      `The plugin sent screenshot data as ${typeof result.data}, not a base64 string`
    );
  }

  let pngBase64: string;
  if (result.format === 'rgba') {
    const rgbaBuffer = Buffer.from(result.data, 'base64');
    const pngBuffer = rgbaToPng(rgbaBuffer, result.width, result.height);
    pngBase64 = pngBuffer.toString('base64');
  } else {
    pngBase64 = result.data;
  }

  return {
    data: pngBase64,
    width: result.width ?? 0,
    height: result.height ?? 0,
    source: 'captureService',
    summary: `Screenshot captured (${result.width ?? 0}x${result.height ?? 0})`,
  };
}

export const screenshotCommand = defineCommand<ViewportArgs, ScreenshotResult>({
  group: 'viewport',
  name: 'screenshot',
  description: 'Capture a viewport screenshot from Studio',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: { ...viewportArgs },
  cli: {
    binaryField: 'data',
    json: (result) =>
      formatJson(
        {
          width: result.width,
          height: result.height,
          source: result.source,
          summary: result.summary,
        },
        { pretty: process.stdout.isTTY }
      ),
  },
  handler: async (session, args, connection) =>
    captureScreenshotHandlerAsync(
      session,
      toViewportReadOptions(args),
      connection
    ),
});
