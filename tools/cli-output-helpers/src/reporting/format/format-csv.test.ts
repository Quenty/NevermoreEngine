import { describe, it, expect } from 'vitest';
import { formatCsv, toCsvField } from './format-csv.js';

describe('formatCsv', () => {
  it('writes a header, one line per row and a trailing newline', () => {
    expect(
      formatCsv(
        ['name', 'count', 'on'],
        [
          ['a', 1, true],
          ['b', 0.5, false],
        ]
      )
    ).toBe('name,count,on\na,1,true\nb,0.5,false\n');
  });

  it('writes just the header for no rows', () => {
    expect(formatCsv(['a', 'b'], [])).toBe('a,b\n');
  });
});

describe('toCsvField', () => {
  it('leaves plain text alone', () => {
    expect(toCsvField('Size.X.Scale')).toBe('Size.X.Scale');
  });

  it.each([
    ['a, b', '"a, b"'],
    ['say "hi"', '"say ""hi"""'],
    ['two\nlines', '"two\nlines"'],
  ])('quotes %j', (value, expected) => {
    expect(toCsvField(value)).toBe(expected);
  });
});
