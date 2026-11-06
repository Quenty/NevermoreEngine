/**
 * Lays recorded frames out in a grid, each with a label strip under it, and a
 * header line across the top, so a recording can be judged at a glance from
 * one image.
 */

import {
  drawText,
  fillRect,
  measureText,
  type Rgba,
  type RgbaImage,
} from './bitmap-font.js';

/** The sheet is scaled down to fit within this in both directions. */
const MAX_SHEET_SIZE = 2048;
/** The shape the column count aims for. */
const TARGET_ASPECT = 4 / 3;
const GAP = 4;
const TEXT_PIXEL_SIZE = 2;
const TEXT_PADDING = 4;

const BACKGROUND: Rgba = [24, 24, 24, 255];
const TEXT_COLOR: Rgba = [235, 235, 235, 255];

export interface SheetFrame extends RgbaImage {
  /** Drawn under the frame, e.g. `0.268s · f4`. */
  label: string;
}

export interface ContactSheetOptions {
  /** Drawn across the top, e.g. `6 of 19 captured · 5.0/s · 1.201s`. */
  header?: string;
}

interface Layout {
  columns: number;
  rows: number;
  cellWidth: number;
  cellHeight: number;
}

/**
 * Picks `count` indices spread evenly from 0 to `total - 1`, first and last
 * included.
 */
export function pickEvenlySpaced(total: number, count: number): number[] {
  if (total <= 0 || count <= 0) return [];
  if (count >= total) return [...Array(total).keys()];
  if (count === 1) return [0];

  const indices: number[] = [];
  for (let i = 0; i < count; i++) {
    indices.push(Math.round((i * (total - 1)) / (count - 1)));
  }
  return indices;
}

/** Formats a recording time, e.g. `0.233s`. */
export function formatTimeLabel(seconds: number): string {
  return `${seconds.toFixed(3)}s`;
}

/** The label under a frame: its time and frame number, e.g. `0.268s · f4`. */
export function formatFrameLabel(t: number, frame: number): string {
  return `${formatTimeLabel(t)} · f${frame}`;
}

const TEXT_HEIGHT = measureText('', TEXT_PIXEL_SIZE).height;
const LABEL_STRIP_HEIGHT = TEXT_HEIGHT + TEXT_PADDING * 2;

/**
 * Builds the sheet. Cells are as large as the largest frame, with as many
 * columns as bring the sheet closest to 4:3, then scaled down to fit 2048
 * pixels each way.
 */
export function buildContactSheet(
  frames: SheetFrame[],
  options: ContactSheetOptions = {}
): RgbaImage {
  if (frames.length === 0) {
    throw new Error('A contact sheet needs at least one frame');
  }

  const headerHeight = options.header ? LABEL_STRIP_HEIGHT : 0;
  const headerWidth = options.header
    ? measureText(options.header, TEXT_PIXEL_SIZE).width + GAP * 2
    : 0;
  const layout = chooseLayout(
    frames.length,
    Math.max(...frames.map((f) => f.width)),
    Math.max(...frames.map((f) => f.height)),
    headerHeight
  );

  const gridWidth =
    layout.columns * layout.cellWidth + (layout.columns + 1) * GAP;
  const sheet: RgbaImage = {
    width: Math.max(gridWidth, headerWidth),
    height:
      headerHeight +
      layout.rows * (layout.cellHeight + LABEL_STRIP_HEIGHT) +
      (layout.rows + 1) * GAP,
    rgba: Buffer.alloc(0),
  };
  sheet.rgba = Buffer.alloc(sheet.width * sheet.height * 4);
  fillRect(sheet, 0, 0, sheet.width, sheet.height, BACKGROUND);

  if (options.header) {
    drawText(
      sheet,
      options.header,
      GAP,
      TEXT_PADDING,
      TEXT_PIXEL_SIZE,
      TEXT_COLOR
    );
  }

  frames.forEach((frame, index) => {
    const x = GAP + (index % layout.columns) * (layout.cellWidth + GAP);
    const y =
      headerHeight +
      GAP +
      Math.floor(index / layout.columns) *
        (layout.cellHeight + LABEL_STRIP_HEIGHT + GAP);
    blitScaled(sheet, frame, x, y, layout.cellWidth, layout.cellHeight);

    // Smaller text where the full size would run past the tile
    const pixelSize =
      measureText(frame.label, TEXT_PIXEL_SIZE).width <= layout.cellWidth
        ? TEXT_PIXEL_SIZE
        : 1;
    const labelY =
      y +
      layout.cellHeight +
      Math.floor((LABEL_STRIP_HEIGHT - measureText('', pixelSize).height) / 2);
    drawText(sheet, frame.label, x, labelY, pixelSize, TEXT_COLOR);
  });

  return sheet;
}

/**
 * Picks the column count whose sheet comes closest to 4:3, then the cell size
 * that fits the sheet within the size limit.
 */
function chooseLayout(
  count: number,
  frameWidth: number,
  frameHeight: number,
  headerHeight: number
): Layout {
  let best = { columns: 1, score: Infinity };
  for (let columns = 1; columns <= count; columns++) {
    const rows = Math.ceil(count / columns);
    const width = columns * frameWidth + (columns + 1) * GAP;
    const height =
      headerHeight +
      rows * (frameHeight + LABEL_STRIP_HEIGHT) +
      (rows + 1) * GAP;
    const score = Math.abs(Math.log(width / height / TARGET_ASPECT));
    if (score < best.score) {
      best = { columns, score };
    }
  }

  const columns = best.columns;
  const rows = Math.ceil(count / columns);
  const roomWidth = MAX_SHEET_SIZE - (columns + 1) * GAP;
  const roomHeight =
    MAX_SHEET_SIZE -
    headerHeight -
    rows * LABEL_STRIP_HEIGHT -
    (rows + 1) * GAP;
  const scale = Math.min(
    1,
    roomWidth / (columns * frameWidth),
    Math.max(roomHeight, rows) / (rows * frameHeight)
  );

  return {
    columns,
    rows,
    cellWidth: Math.max(1, Math.floor(frameWidth * scale)),
    cellHeight: Math.max(1, Math.floor(frameHeight * scale)),
  };
}

/**
 * Copies `source` into a `width` x `height` area of `target` at `x`, `y`,
 * scaled by nearest neighbour.
 */
function blitScaled(
  target: RgbaImage,
  source: RgbaImage,
  x: number,
  y: number,
  width: number,
  height: number
): void {
  const scaleX = source.width / width;
  const scaleY = source.height / height;
  for (let row = 0; row < height; row++) {
    const targetY = y + row;
    if (targetY >= target.height) break;
    const sourceRow = Math.min(source.height - 1, Math.floor(row * scaleY));
    for (let column = 0; column < width; column++) {
      const targetX = x + column;
      if (targetX >= target.width) break;
      const sourceColumn = Math.min(
        source.width - 1,
        Math.floor(column * scaleX)
      );
      const from = (sourceRow * source.width + sourceColumn) * 4;
      source.rgba.copy(
        target.rgba,
        (targetY * target.width + targetX) * 4,
        from,
        from + 4
      );
    }
  }
}
