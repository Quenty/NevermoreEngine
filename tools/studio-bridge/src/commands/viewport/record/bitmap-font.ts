/**
 * A 5x7 pixel font (plus two descender rows), drawn straight into RGBA pixels so the contact sheet
 * needs no image or font dependency. It has digits, lowercase letters and the
 * punctuation the sheet's labels use (`0.268s · f4`, `5.0/s`).
 *
 * Lowercase letters sit in the lower five rows, so `s` reads apart from `5`,
 * and `3` is open on the left where `8` is closed.
 */

const GLYPH_WIDTH = 5;
// Seven rows above the baseline, two below it for g, j, p, q and y
const GLYPH_HEIGHT = 9;
const GLYPH_SPACING = 1;

// One string per row, '#' for a lit pixel
const GLYPHS: Record<string, string[]> = {
  '0': ['.###.', '#...#', '#..##', '#.#.#', '##..#', '#...#', '.###.'],
  '1': ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'],
  '2': ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'],
  '3': ['####.', '....#', '....#', '.###.', '....#', '....#', '####.'],
  '4': ['...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.'],
  '5': ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.'],
  '6': ['..##.', '.#...', '#....', '####.', '#...#', '#...#', '.###.'],
  '7': ['#####', '....#', '...#.', '..#..', '.#...', '.#...', '.#...'],
  '8': ['.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'],
  '9': ['.###.', '#...#', '#...#', '.####', '....#', '...#.', '.##..'],
  a: ['.....', '.....', '.###.', '....#', '.####', '#...#', '.####'],
  b: ['#....', '#....', '####.', '#...#', '#...#', '#...#', '####.'],
  c: ['.....', '.....', '.###.', '#....', '#....', '#...#', '.###.'],
  d: ['....#', '....#', '.####', '#...#', '#...#', '#...#', '.####'],
  e: ['.....', '.....', '.###.', '#...#', '#####', '#....', '.###.'],
  f: ['..##.', '.#..#', '.#...', '###..', '.#...', '.#...', '.#...'],
  g: [
    '.....',
    '.....',
    '.####',
    '#...#',
    '#...#',
    '#...#',
    '.####',
    '....#',
    '.###.',
  ],
  h: ['#....', '#....', '#.##.', '##..#', '#...#', '#...#', '#...#'],
  i: ['..#..', '.....', '.##..', '..#..', '..#..', '..#..', '.###.'],
  j: [
    '...#.',
    '.....',
    '..##.',
    '...#.',
    '...#.',
    '...#.',
    '...#.',
    '#..#.',
    '.##..',
  ],
  k: ['#....', '#....', '#..#.', '#.#..', '##...', '#.#..', '#..#.'],
  l: ['.##..', '..#..', '..#..', '..#..', '..#..', '..#..', '.###.'],
  m: ['.....', '.....', '##.#.', '#.#.#', '#.#.#', '#...#', '#...#'],
  n: ['.....', '.....', '#.##.', '##..#', '#...#', '#...#', '#...#'],
  o: ['.....', '.....', '.###.', '#...#', '#...#', '#...#', '.###.'],
  p: [
    '.....',
    '.....',
    '####.',
    '#...#',
    '#...#',
    '#...#',
    '####.',
    '#....',
    '#....',
  ],
  q: [
    '.....',
    '.....',
    '.####',
    '#...#',
    '#...#',
    '#...#',
    '.####',
    '....#',
    '....#',
  ],
  r: ['.....', '.....', '#.##.', '##..#', '#....', '#....', '#....'],
  s: ['.....', '.....', '.####', '#....', '.###.', '....#', '####.'],
  t: ['.#...', '.#...', '###..', '.#...', '.#...', '.#..#', '..##.'],
  u: ['.....', '.....', '#...#', '#...#', '#...#', '#..##', '.##.#'],
  v: ['.....', '.....', '#...#', '#...#', '#...#', '.#.#.', '..#..'],
  w: ['.....', '.....', '#...#', '#...#', '#.#.#', '#.#.#', '.#.#.'],
  x: ['.....', '.....', '#...#', '.#.#.', '..#..', '.#.#.', '#...#'],
  y: [
    '.....',
    '.....',
    '#...#',
    '#...#',
    '#...#',
    '#...#',
    '.####',
    '....#',
    '.###.',
  ],
  z: ['.....', '.....', '#####', '...#.', '..#..', '.#...', '#####'],
  ' ': ['.....', '.....', '.....', '.....', '.....', '.....', '.....'],
  '.': ['.....', '.....', '.....', '.....', '.....', '.##..', '.##..'],
  '·': ['.....', '.....', '.....', '.##..', '.##..', '.....', '.....'],
  '/': ['....#', '....#', '...#.', '..#..', '.#...', '#....', '#....'],
  ':': ['.....', '.##..', '.##..', '.....', '.##..', '.##..', '.....'],
  '-': ['.....', '.....', '.....', '#####', '.....', '.....', '.....'],
  '(': ['...#.', '..#..', '.#...', '.#...', '.#...', '..#..', '...#.'],
  ')': ['.#...', '..#..', '...#.', '...#.', '...#.', '..#..', '.#...'],
};

export interface RgbaImage {
  rgba: Buffer;
  width: number;
  height: number;
}

export type Rgba = [number, number, number, number];

/** The size `text` takes when drawn at `pixelSize`. */
export function measureText(
  text: string,
  pixelSize: number
): { width: number; height: number } {
  const glyphs = [...text].length;
  return {
    width:
      glyphs === 0
        ? 0
        : (glyphs * (GLYPH_WIDTH + GLYPH_SPACING) - GLYPH_SPACING) * pixelSize,
    height: GLYPH_HEIGHT * pixelSize,
  };
}

/**
 * Draws `text` with its top-left corner at `x`, `y`, each font pixel a
 * `pixelSize` square. Uppercase letters draw as lowercase. Throws on a
 * character the font lacks; pixels outside the image are clipped.
 */
export function drawText(
  image: RgbaImage,
  text: string,
  x: number,
  y: number,
  pixelSize: number,
  color: Rgba
): void {
  let penX = x;
  for (const char of text.toLowerCase()) {
    const glyph = GLYPHS[char];
    if (!glyph) {
      throw new Error(`The bitmap font has no glyph for '${char}'`);
    }

    for (let row = 0; row < glyph.length; row++) {
      for (let column = 0; column < GLYPH_WIDTH; column++) {
        if (glyph[row][column] === '#') {
          fillRect(
            image,
            penX + column * pixelSize,
            y + row * pixelSize,
            pixelSize,
            pixelSize,
            color
          );
        }
      }
    }
    penX += (GLYPH_WIDTH + GLYPH_SPACING) * pixelSize;
  }
}

/** Fills a rectangle, clipped to the image. */
export function fillRect(
  image: RgbaImage,
  x: number,
  y: number,
  width: number,
  height: number,
  color: Rgba
): void {
  const left = Math.max(0, x);
  const top = Math.max(0, y);
  const right = Math.min(image.width, x + width);
  const bottom = Math.min(image.height, y + height);
  for (let py = top; py < bottom; py++) {
    for (let px = left; px < right; px++) {
      const offset = (py * image.width + px) * 4;
      image.rgba[offset] = color[0];
      image.rgba[offset + 1] = color[1];
      image.rgba[offset + 2] = color[2];
      image.rgba[offset + 3] = color[3];
    }
  }
}
