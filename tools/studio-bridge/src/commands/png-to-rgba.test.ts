import { deflateSync } from 'zlib';
import { describe, it, expect } from 'vitest';
import { pngToRgba } from './png-to-rgba.js';
import { rgbaToPng } from './rgba-to-png.js';

/** Builds a PNG chunk; the decoder does not check CRCs, so it is left 0. */
function chunk(type: string, data: Buffer): Buffer {
  const header = Buffer.alloc(8);
  header.writeUInt32BE(data.length, 0);
  header.write(type, 4, 'ascii');
  return Buffer.concat([header, data, Buffer.alloc(4)]);
}

function png(
  width: number,
  height: number,
  colorType: number,
  scanlines: Buffer
): Buffer {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = colorType;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(scanlines)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

describe('pngToRgba', () => {
  it('round-trips rgbaToPng', () => {
    const rgba = Buffer.from([...Array(3 * 2 * 4).keys()]);

    const decoded = pngToRgba(rgbaToPng(rgba, 3, 2));

    expect(decoded.width).toBe(3);
    expect(decoded.height).toBe(2);
    expect([...decoded.rgba]).toEqual([...rgba]);
  });

  it('undoes Sub, Up, Average and Paeth filters', () => {
    // 2x4 RGBA, one row per filter; every pixel is (10, 20, 30, 255)
    const pixel = [10, 20, 30, 255];
    const rows = [
      // Sub: second pixel stores the difference from the first, which is 0
      [1, ...pixel, 0, 0, 0, 0],
      // Up: everything matches the row above
      [2, 0, 0, 0, 0, 0, 0, 0, 0],
      // Average: floor((left + up) / 2) is the pixel itself
      [3, 5, 10, 15, 128, 0, 0, 0, 0],
      // Paeth: predicts the pixel exactly
      [4, 0, 0, 0, 0, 0, 0, 0, 0],
    ];

    const decoded = pngToRgba(png(2, 4, 6, Buffer.from(rows.flat())));

    expect([...decoded.rgba]).toEqual(Array(8).fill(pixel).flat());
  });

  it('adds opaque alpha to RGB', () => {
    const decoded = pngToRgba(png(1, 1, 2, Buffer.from([0, 1, 2, 3])));

    expect([...decoded.rgba]).toEqual([1, 2, 3, 255]);
  });

  it('refuses what is not a PNG', () => {
    expect(() => pngToRgba(Buffer.from('nope'))).toThrow('Not a PNG');
  });
});
