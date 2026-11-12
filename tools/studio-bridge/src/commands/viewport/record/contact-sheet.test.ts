import { describe, it, expect } from 'vitest';
import {
  buildContactSheet,
  formatFrameLabel,
  formatTimeLabel,
  pickEvenlySpaced,
} from './contact-sheet.js';
import { drawText, measureText } from './bitmap-font.js';

const GAP = 4;
const LABEL_STRIP = 9 * 2 + 4 * 2;
const BACKGROUND = [24, 24, 24, 255];

function solid(width: number, height: number, value: number) {
  return { rgba: Buffer.alloc(width * height * 4, value), width, height };
}

function frames(count: number, width: number, height: number) {
  return [...Array(count).keys()].map((i) => ({
    ...solid(width, height, 100 + i),
    label: formatFrameLabel(i / 10, i * 3),
  }));
}

function pixelAt(
  image: { rgba: Buffer; width: number },
  x: number,
  y: number
): number[] {
  const offset = (y * image.width + x) * 4;
  return [...image.rgba.subarray(offset, offset + 4)];
}

function columnsOf(sheetWidth: number, cellWidth: number): number {
  return Math.round((sheetWidth - GAP) / (cellWidth + GAP));
}

describe('pickEvenlySpaced', () => {
  it('includes the first and last', () => {
    expect(pickEvenlySpaced(10, 4)).toEqual([0, 3, 6, 9]);
  });

  it('takes everything when asked for more than there is', () => {
    expect(pickEvenlySpaced(3, 16)).toEqual([0, 1, 2]);
  });

  it('takes nothing for 0', () => {
    expect(pickEvenlySpaced(3, 0)).toEqual([]);
  });
});

describe('labels', () => {
  it('shows milliseconds', () => {
    expect(formatTimeLabel(0.2333)).toBe('0.233s');
  });

  it('adds the frame number', () => {
    expect(formatFrameLabel(0.268, 4)).toBe('0.268s · f4');
  });
});

describe('drawText', () => {
  it('lights the pixels of a glyph', () => {
    const image = solid(5, 7, 0);

    drawText(image, '1', 0, 0, 1, [255, 255, 255, 255]);

    expect(pixelAt(image, 0, 0)).toEqual([0, 0, 0, 0]);
    expect(pixelAt(image, 2, 0)).toEqual([255, 255, 255, 255]);
  });

  it('draws s and 5, and 3 and 8, differently', () => {
    const draw = (char: string) => {
      const image = solid(5, 7, 0);
      drawText(image, char, 0, 0, 1, [255, 255, 255, 255]);
      return image.rgba.toString('hex');
    };

    expect(draw('s')).not.toBe(draw('5'));
    expect(draw('3')).not.toBe(draw('8'));
  });

  it('draws every character the sheet uses', () => {
    expect(() =>
      drawText(
        solid(400, 7, 0),
        '6 of 19 captured · 5.0/s · 1.201s · 2 skipped f4',
        0,
        0,
        1,
        [0, 0, 0, 0]
      )
    ).not.toThrow();
  });

  it('refuses a character it has no glyph for', () => {
    expect(() =>
      drawText(solid(10, 10, 0), '#', 0, 0, 1, [0, 0, 0, 0])
    ).toThrow("no glyph for '#'");
  });

  it('measures text', () => {
    expect(measureText('0.5s', 2)).toEqual({ width: 46, height: 18 });
  });
});

describe('buildContactSheet', () => {
  it('puts each label in a strip under its tile, clear of the image', () => {
    const sheet = buildContactSheet(frames(4, 200, 100));

    expect(sheet.width).toBe(2 * 200 + 3 * GAP);
    expect(sheet.height).toBe(2 * (100 + LABEL_STRIP) + 3 * GAP);
    expect(pixelAt(sheet, GAP, GAP)).toEqual([100, 100, 100, 100]);
    const stripY = GAP + 100;
    const strip = [...Array(LABEL_STRIP).keys()].flatMap((dy) =>
      [...Array(200).keys()].map((dx) =>
        pixelAt(sheet, GAP + dx, stripY + dy).join()
      )
    );
    expect(strip).toContain(BACKGROUND.join());
    expect(strip).toContain([235, 235, 235, 255].join());
  });

  it('draws the header across the top', () => {
    const withHeader = buildContactSheet(frames(4, 200, 100), {
      header: '4 of 9 captured',
    });
    const without = buildContactSheet(frames(4, 200, 100));

    expect(withHeader.height).toBe(without.height + LABEL_STRIP);
  });

  it('lays 16:9 frames out in about four columns, as before', () => {
    const sheet = buildContactSheet(frames(16, 160, 90));

    expect(columnsOf(sheet.width, 160)).toBe(4);
  });

  it('stacks wide strips in one or two columns', () => {
    const sheet = buildContactSheet(frames(16, 1920, 120));
    const cellWidth = Math.floor(1920 * Math.min(1, (2048 - 2 * GAP) / 1920));

    expect(columnsOf(sheet.width, cellWidth)).toBeLessThanOrEqual(2);
    expect(sheet.width).toBeLessThanOrEqual(2048);
    expect(sheet.height).toBeLessThanOrEqual(2048 + LABEL_STRIP);
  });

  it('scales cells down to keep the sheet within 2048 pixels', () => {
    const sheet = buildContactSheet(frames(4, 1600, 900));

    expect(sheet.width).toBeLessThanOrEqual(2048);
    expect(sheet.height).toBeLessThanOrEqual(2048);
    expect(sheet.rgba.length).toBe(sheet.width * sheet.height * 4);
  });
});
