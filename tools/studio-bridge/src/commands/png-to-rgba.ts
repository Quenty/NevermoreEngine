/**
 * Minimal PNG decoder, the inverse of `rgbaToPng`, for the frames
 * `viewport record` lays out on its contact sheet. Studio encodes them with
 * its own PNG encoder.
 *
 * Reads 8-bit RGBA and RGB, non-interlaced, with any scanline filter. Uses
 * only Node.js built-ins (zlib, Buffer).
 */

import { inflateSync } from 'zlib';

const SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

const CHANNELS_BY_COLOR_TYPE: Record<number, number> = {
  2: 3, // RGB
  6: 4, // RGBA
};

export interface DecodedPng {
  rgba: Buffer;
  width: number;
  height: number;
}

/** Decodes a PNG into raw RGBA (4 bytes per pixel, row-major). */
export function pngToRgba(png: Buffer): DecodedPng {
  if (png.length < 8 || !png.subarray(0, 8).equals(SIGNATURE)) {
    throw new Error('Not a PNG: the signature is missing');
  }

  let width = 0;
  let height = 0;
  let channels = 0;
  const idat: Buffer[] = [];

  let offset = 8;
  while (offset + 8 <= png.length) {
    const length = png.readUInt32BE(offset);
    const type = png.toString('ascii', offset + 4, offset + 8);
    const data = png.subarray(offset + 8, offset + 8 + length);
    offset += 12 + length;

    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      const bitDepth = data[8];
      const colorType = data[9];
      const interlace = data[12];
      channels = CHANNELS_BY_COLOR_TYPE[colorType] ?? 0;
      if (bitDepth !== 8 || channels === 0 || interlace !== 0) {
        throw new Error(
          `Unsupported PNG: bit depth ${bitDepth}, color type ${colorType}, interlace ${interlace}`
        );
      }
    } else if (type === 'IDAT') {
      idat.push(data);
    } else if (type === 'IEND') {
      break;
    }
  }

  if (channels === 0) {
    throw new Error('Not a PNG: the IHDR chunk is missing');
  }

  const raw = inflateSync(Buffer.concat(idat));
  const pixels = unfilter(raw, width, height, channels);
  return { rgba: toRgba(pixels, channels), width, height };
}

/** Undoes each scanline's filter, returning the bare pixel bytes. */
function unfilter(
  raw: Buffer,
  width: number,
  height: number,
  bytesPerPixel: number
): Buffer {
  const stride = width * bytesPerPixel;
  if (raw.length < height * (stride + 1)) {
    throw new Error('Corrupt PNG: the image data is too short');
  }

  const out = Buffer.alloc(height * stride);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const inRow = y * (stride + 1) + 1;
    const outRow = y * stride;
    const prevRow = outRow - stride;

    for (let x = 0; x < stride; x++) {
      const left = x >= bytesPerPixel ? out[outRow + x - bytesPerPixel] : 0;
      const up = y > 0 ? out[prevRow + x] : 0;
      const upLeft =
        y > 0 && x >= bytesPerPixel ? out[prevRow + x - bytesPerPixel] : 0;

      let predictor: number;
      switch (filter) {
        case 0:
          predictor = 0;
          break;
        case 1:
          predictor = left;
          break;
        case 2:
          predictor = up;
          break;
        case 3:
          predictor = (left + up) >> 1;
          break;
        case 4:
          predictor = paeth(left, up, upLeft);
          break;
        default:
          throw new Error(`Corrupt PNG: unknown filter ${filter}`);
      }
      out[outRow + x] = (raw[inRow + x] + predictor) & 0xff;
    }
  }
  return out;
}

function paeth(left: number, up: number, upLeft: number): number {
  const estimate = left + up - upLeft;
  const toLeft = Math.abs(estimate - left);
  const toUp = Math.abs(estimate - up);
  const toUpLeft = Math.abs(estimate - upLeft);
  if (toLeft <= toUp && toLeft <= toUpLeft) return left;
  if (toUp <= toUpLeft) return up;
  return upLeft;
}

function toRgba(pixels: Buffer, channels: number): Buffer {
  if (channels === 4) return pixels;

  const count = pixels.length / channels;
  const rgba = Buffer.alloc(count * 4);
  for (let i = 0; i < count; i++) {
    rgba[i * 4] = pixels[i * channels];
    rgba[i * 4 + 1] = pixels[i * channels + 1];
    rgba[i * 4 + 2] = pixels[i * channels + 2];
    rgba[i * 4 + 3] = 255;
  }
  return rgba;
}
