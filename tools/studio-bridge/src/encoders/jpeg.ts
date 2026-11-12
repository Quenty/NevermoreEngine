import jpeg from 'jpeg-js';
import type { DecodedPng } from './png.js';

export function jpegToRgba(data: Buffer): DecodedPng {
  const decoded = jpeg.decode(data, { formatAsRGBA: true });
  return {
    rgba: decoded.data,
    width: decoded.width,
    height: decoded.height,
  };
}
