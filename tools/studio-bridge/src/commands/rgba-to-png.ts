/**
 * Minimal PNG encoder that converts raw RGBA pixel data into a valid PNG file.
 *
 * Uses only Node.js built-ins (zlib, Buffer). Produces unfiltered scanlines
 * (filter byte 0 per row) compressed with deflate — not optimal file size,
 * but correct and dependency-free.
 */

import { deflateSync } from 'zlib';

// PNG uses network byte order (big-endian)
function writeU32BE(buf: Buffer, offset: number, value: number): void {
  buf[offset] = (value >>> 24) & 0xff;
  buf[offset + 1] = (value >>> 16) & 0xff;
  buf[offset + 2] = (value >>> 8) & 0xff;
  buf[offset + 3] = value & 0xff;
}

// CRC-32 lookup table (ISO 3309 / ITU-T V.42 polynomial)
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

/** Build a PNG chunk: length(4) + type(4) + data + crc32(4). */
function makeChunk(type: string, data: Buffer): Buffer {
  const typeBytes = Buffer.from(type, 'ascii');
  const chunk = Buffer.alloc(4 + 4 + data.length + 4);
  writeU32BE(chunk, 0, data.length);
  typeBytes.copy(chunk, 4);
  data.copy(chunk, 8);
  // CRC covers type + data
  const crcInput = Buffer.alloc(4 + data.length);
  typeBytes.copy(crcInput, 0);
  data.copy(crcInput, 4);
  writeU32BE(chunk, 8 + data.length, crc32(crcInput));
  return chunk;
}

/**
 * Convert raw RGBA pixel data to a PNG file buffer.
 *
 * @param rgba - Raw RGBA bytes (4 bytes per pixel, row-major, top-to-bottom)
 * @param width - Image width in pixels
 * @param height - Image height in pixels
 * @returns A Buffer containing a valid PNG file
 */
export function rgbaToPng(rgba: Buffer, width: number, height: number): Buffer {
  const expectedBytes = width * height * 4;
  if (rgba.length !== expectedBytes) {
    throw new Error(
      `RGBA data length mismatch: expected ${expectedBytes} bytes (${width}x${height}x4), got ${rgba.length}`,
    );
  }

  // PNG signature
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR: width(4) + height(4) + bitDepth(1) + colorType(1) + compression(1) + filter(1) + interlace(1)
  const ihdrData = Buffer.alloc(13);
  writeU32BE(ihdrData, 0, width);
  writeU32BE(ihdrData, 4, height);
  ihdrData[8] = 8; // 8 bits per channel
  ihdrData[9] = 6; // RGBA color type
  ihdrData[10] = 0; // deflate compression
  ihdrData[11] = 0; // adaptive filtering
  ihdrData[12] = 0; // no interlace
  const ihdr = makeChunk('IHDR', ihdrData);

  // Build raw scanlines: each row gets a filter byte (0 = None) prefix
  const rowBytes = width * 4;
  const rawData = Buffer.alloc(height * (1 + rowBytes));
  for (let y = 0; y < height; y++) {
    const outOffset = y * (1 + rowBytes);
    rawData[outOffset] = 0; // filter: None
    rgba.copy(rawData, outOffset + 1, y * rowBytes, (y + 1) * rowBytes);
  }

  const compressed = deflateSync(rawData);
  const idat = makeChunk('IDAT', compressed);

  // IEND: empty chunk
  const iend = makeChunk('IEND', Buffer.alloc(0));

  return Buffer.concat([signature, ihdr, idat, iend]);
}
