import { describe, it, expect } from 'vitest';
import jpeg from 'jpeg-js';
import { jpegToRgba } from './jpeg.js';

describe('jpegToRgba', () => {
  it('decodes a JPEG into RGBA of its size', () => {
    const rgba = Buffer.alloc(4 * 3 * 4, 0);
    for (let i = 0; i < rgba.length; i += 4) {
      rgba[i] = 250;
      rgba[i + 3] = 255;
    }
    const encoded = jpeg.encode({ data: rgba, width: 4, height: 3 }, 100).data;

    const decoded = jpegToRgba(encoded);

    expect(decoded.width).toBe(4);
    expect(decoded.height).toBe(3);
    expect(decoded.rgba.length).toBe(4 * 3 * 4);
    expect(decoded.rgba[0]).toBeGreaterThan(240);
    expect(decoded.rgba[3]).toBe(255);
  });
});
