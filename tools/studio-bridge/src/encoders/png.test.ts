import { deflateSync } from 'zlib';
import { describe, it, expect } from 'vitest';
import { pngToRgba, rgbaToPng } from './png.js';

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
    const rgba = Buffer.from([255, 0, 0, 255]);
    const png = rgbaToPng(rgba, 1, 1);

    expect(png[0]).toBe(137);
    expect(png.toString('ascii', 1, 4)).toBe('PNG');
    expect(png.length).toBeGreaterThan(8);
  });

  it('produces a valid PNG for a 2x2 image', () => {
    const rgba = Buffer.alloc(16, 0);
    for (let i = 0; i < 4; i++) {
      rgba[i * 4 + 2] = 255;
      rgba[i * 4 + 3] = 255;
    }
    const png = rgbaToPng(rgba, 2, 2);

    expect(png.subarray(0, 4)).toEqual(Buffer.from([137, 80, 78, 71]));
  });

  it('throws on data length mismatch', () => {
    const rgba = Buffer.alloc(10);
    expect(() => rgbaToPng(rgba, 2, 2)).toThrow('data length mismatch');
  });

  it('round-trips: PNG starts with signature and ends with IEND', () => {
    const rgba = Buffer.alloc(4 * 4 * 4, 128);
    const png = rgbaToPng(rgba, 4, 4);

    expect(png.subarray(0, 8)).toEqual(
      Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])
    );

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
    const pixel = [10, 20, 30, 255];
    const rows = [
      [1, ...pixel, 0, 0, 0, 0],
      [2, 0, 0, 0, 0, 0, 0, 0, 0],
      [3, 5, 10, 15, 128, 0, 0, 0, 0],
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
