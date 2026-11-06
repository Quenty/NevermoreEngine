import { deflateSync } from 'zlib';
import { describe, it, expect } from 'vitest';
import { pngToRgba, rgbaToPng } from './png.js';

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

describe('rgbaToPng', () => {
  it('produces a valid PNG for a 1x1 red pixel', () => {
    // 1x1 RGBA: red pixel (255, 0, 0, 255)
    const rgba = Buffer.from([255, 0, 0, 255]);
    const png = rgbaToPng(rgba, 1, 1);

    // Check PNG signature
    expect(png[0]).toBe(137);
    expect(png[1]).toBe(80); // 'P'
    expect(png[2]).toBe(78); // 'N'
    expect(png[3]).toBe(71); // 'G'
    expect(png.length).toBeGreaterThan(8);
  });

  it('produces a valid PNG for a 2x2 image', () => {
    // 2x2 RGBA: 4 pixels * 4 bytes = 16 bytes
    const rgba = Buffer.alloc(16, 0);
    // Set all pixels to blue (0, 0, 255, 255)
    for (let i = 0; i < 4; i++) {
      rgba[i * 4 + 2] = 255;
      rgba[i * 4 + 3] = 255;
    }
    const png = rgbaToPng(rgba, 2, 2);

    // Check PNG signature
    expect(png.subarray(0, 4)).toEqual(Buffer.from([137, 80, 78, 71]));
  });

  it('throws on data length mismatch', () => {
    const rgba = Buffer.alloc(10); // Wrong size for any dimensions
    expect(() => rgbaToPng(rgba, 2, 2)).toThrow('data length mismatch');
  });

  it('round-trips: PNG starts with signature and ends with IEND', () => {
    const rgba = Buffer.alloc(4 * 4 * 4, 128); // 4x4 gray pixels
    const png = rgbaToPng(rgba, 4, 4);

    // Signature
    expect(png.subarray(0, 8)).toEqual(
      Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])
    );

    // IEND chunk at end: length(0) + "IEND" + CRC
    const iendType = png
      .subarray(png.length - 8, png.length - 4)
      .toString('ascii');
    expect(iendType).toBe('IEND');
  });
});

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
