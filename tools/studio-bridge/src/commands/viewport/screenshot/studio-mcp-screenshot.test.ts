import { describe, it, expect } from 'vitest';
import { cropAndScale } from './studio-mcp-screenshot.js';

function image(width: number, height: number) {
  const rgba = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      rgba.set([x, y, 0, 255], (y * width + x) * 4);
    }
  }
  return { rgba, width, height };
}

function pixel(img: { rgba: Buffer; width: number }, x: number, y: number) {
  const i = (y * img.width + x) * 4;
  return [img.rgba[i], img.rgba[i + 1]];
}

describe('cropAndScale', () => {
  it('returns the whole image without options', () => {
    const result = cropAndScale(image(4, 3), {});
    expect([result.width, result.height]).toEqual([4, 3]);
    expect(pixel(result, 3, 2)).toEqual([3, 2]);
  });

  it('crops to the region, clamped to the image', () => {
    const result = cropAndScale(image(8, 8), { region: [6, 5, 10, 10] });
    expect([result.width, result.height]).toEqual([2, 3]);
    expect(pixel(result, 0, 0)).toEqual([6, 5]);
  });

  it('scales after cropping', () => {
    const result = cropAndScale(image(8, 8), {
      region: [4, 0, 4, 8],
      scale: 0.5,
    });
    expect([result.width, result.height]).toEqual([2, 4]);
    expect(pixel(result, 1, 3)).toEqual([6, 6]);
  });

  it('throws when the region misses the image', () => {
    expect(() => cropAndScale(image(4, 4), { region: [10, 0, 2, 2] })).toThrow(
      '--region 10,0,2,2 is outside the 4x4 viewport'
    );
  });
});
