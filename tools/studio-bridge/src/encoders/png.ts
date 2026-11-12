import { deflateSync, inflateSync } from 'zlib';

const SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

const BIT_DEPTH_8 = 8;
const COLOR_TYPE_RGB = 2;
const COLOR_TYPE_RGBA = 6;
const COMPRESSION_DEFLATE = 0;
const FILTER_METHOD_ADAPTIVE = 0;
const INTERLACE_NONE = 0;
const SCANLINE_FILTER_NONE = 0;

function writeU32BE(buf: Buffer, offset: number, value: number): void {
  buf[offset] = (value >>> 24) & 0xff;
  buf[offset + 1] = (value >>> 16) & 0xff;
  buf[offset + 2] = (value >>> 8) & 0xff;
  buf[offset + 3] = value & 0xff;
}

const CRC_TABLE: Uint32Array = new Uint32Array(256);
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) {
    c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  }
  CRC_TABLE[n] = c >>> 0;
}

function crc32(data: Buffer): number {
  let crc = 0xffffffff;
  for (let i = 0; i < data.length; i++) {
    crc = CRC_TABLE[(crc ^ data[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function makeChunk(type: string, data: Buffer): Buffer {
  const typeBytes = Buffer.from(type, 'ascii');
  const chunk = Buffer.alloc(4 + 4 + data.length + 4);
  writeU32BE(chunk, 0, data.length);
  typeBytes.copy(chunk, 4);
  data.copy(chunk, 8);
  const crcInput = Buffer.alloc(4 + data.length);
  typeBytes.copy(crcInput, 0);
  data.copy(crcInput, 4);
  writeU32BE(chunk, 8 + data.length, crc32(crcInput));
  return chunk;
}

export function rgbaToPng(rgba: Buffer, width: number, height: number): Buffer {
  const expectedBytes = width * height * 4;
  if (rgba.length !== expectedBytes) {
    throw new Error(
      `RGBA data length mismatch: expected ${expectedBytes} bytes (${width}x${height}x4), got ${rgba.length}`
    );
  }

  const ihdrData = Buffer.alloc(13);
  writeU32BE(ihdrData, 0, width);
  writeU32BE(ihdrData, 4, height);
  ihdrData[8] = BIT_DEPTH_8;
  ihdrData[9] = COLOR_TYPE_RGBA;
  ihdrData[10] = COMPRESSION_DEFLATE;
  ihdrData[11] = FILTER_METHOD_ADAPTIVE;
  ihdrData[12] = INTERLACE_NONE;
  const ihdr = makeChunk('IHDR', ihdrData);

  const rowBytes = width * 4;
  const rawData = Buffer.alloc(height * (1 + rowBytes));
  for (let y = 0; y < height; y++) {
    const outOffset = y * (1 + rowBytes);
    rawData[outOffset] = SCANLINE_FILTER_NONE;
    rgba.copy(rawData, outOffset + 1, y * rowBytes, (y + 1) * rowBytes);
  }

  const compressed = deflateSync(rawData);
  const idat = makeChunk('IDAT', compressed);

  const iend = makeChunk('IEND', Buffer.alloc(0));

  return Buffer.concat([SIGNATURE, ihdr, idat, iend]);
}

const CHANNELS_BY_COLOR_TYPE: Record<number, number> = {
  [COLOR_TYPE_RGB]: 3,
  [COLOR_TYPE_RGBA]: 4,
};

export interface DecodedPng {
  rgba: Buffer;
  width: number;
  height: number;
}

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
      if (
        bitDepth !== BIT_DEPTH_8 ||
        channels === 0 ||
        interlace !== INTERLACE_NONE
      ) {
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
