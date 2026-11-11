import type { BridgeConnection, BridgeSession } from '../../../bridge/index.js';
import { tryCaptureStudioScreenAsync } from '../../../roblox-mcp/index.js';
import {
  jpegToRgba,
  pngToRgba,
  rgbaToPng,
  type DecodedPng,
} from '../../../encoders/index.js';
import type { ViewportReadOptions } from '../../../server/web-socket-protocol.js';
import { resolveStudioMcpTargetAsync } from '../../shared/studio-mcp-target.js';
import {
  invalidInput,
  StudioBridgeError,
} from '../../../messages/studio-bridge-error.js';

export interface StudioMcpScreenshot {
  png: Buffer;
  width: number;
  height: number;
}

export async function captureThroughStudioMcpAsync(
  session: BridgeSession,
  connection: BridgeConnection | undefined,
  options: ViewportReadOptions
): Promise<StudioMcpScreenshot> {
  const result = await tryCaptureStudioScreenAsync(
    await resolveStudioMcpTargetAsync(session, connection)
  );
  if (!result.success) {
    throw new StudioBridgeError({
      code: 'CAPTURE_FAILED',
      message:
        "Studio's MCP server couldn't capture the playtest, and nothing else can.",
      fix: "Check Studio's MCP server is on (Assistant > MCP Servers), or stop the playtest to capture Edit.",
      cause: result.message,
    });
  }

  const { data, mimeType } = result.value;
  const decoded = mimeType === 'image/png' ? pngToRgba(data) : jpegToRgba(data);
  const image = cropAndScale(decoded, options);
  return {
    png: rgbaToPng(image.rgba, image.width, image.height),
    width: image.width,
    height: image.height,
  };
}

export function cropAndScale(
  image: DecodedPng,
  { region, scale = 1 }: ViewportReadOptions
): DecodedPng {
  let left = 0;
  let top = 0;
  let right = image.width;
  let bottom = image.height;
  if (region) {
    left = Math.max(0, Math.floor(region[0]));
    top = Math.max(0, Math.floor(region[1]));
    right = Math.min(image.width, Math.floor(region[0] + region[2]));
    bottom = Math.min(image.height, Math.floor(region[1] + region[3]));
    if (right <= left || bottom <= top) {
      throw invalidInput(
        `--region ${region.join(',')} is outside the ${image.width}x${
          image.height
        } viewport.`,
        `Give a region inside 0,0,${image.width},${image.height}.`
      );
    }
  }

  const regionWidth = right - left;
  const regionHeight = bottom - top;
  const width = Math.max(1, Math.floor(regionWidth * Math.min(scale, 1)));
  const height = Math.max(1, Math.floor(regionHeight * Math.min(scale, 1)));
  const rgba = Buffer.alloc(width * height * 4);
  for (let row = 0; row < height; row++) {
    const sourceRow = top + Math.floor((row * regionHeight) / height);
    for (let column = 0; column < width; column++) {
      const sourceColumn = left + Math.floor((column * regionWidth) / width);
      const from = (sourceRow * image.width + sourceColumn) * 4;
      image.rgba.copy(rgba, (row * width + column) * 4, from, from + 4);
    }
  }
  return { rgba, width, height };
}
