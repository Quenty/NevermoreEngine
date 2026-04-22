import { describe, it, expect } from 'vitest';
import { parseMoonwaveOutput } from './moonwave-parser.js';

describe('parseMoonwaveOutput', () => {
  it('parses a plain error', () => {
    const input = [
      'error: Unknown tag',
      '  ┌─ src/foo.lua:3:3',
      '  │',
      '3 │   @unclosedtag',
      '  │   ^^^^^^^^^^^^ Unknown tag',
    ].join('\n');

    const result = parseMoonwaveOutput(input);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      file: 'src/foo.lua',
      line: 3,
      column: 3,
      severity: 'error',
      message: 'Unknown tag',
      title: 'moonwave',
      source: 'moonwave',
    });
  });

  it('parses output with ANSI color codes', () => {
    // Simulates moonwave-extractor colored output
    const input = [
      '\x1b[0m\x1b[1m\x1b[38;5;9merror\x1b[0m\x1b[1m: Unknown tag\x1b[0m',
      '  \x1b[0m\x1b[34m┌─\x1b[0m src/foo.lua:3:3',
      '  \x1b[0m\x1b[34m│\x1b[0m',
      '\x1b[0m\x1b[34m3\x1b[0m \x1b[0m\x1b[34m│\x1b[0m   \x1b[0m\x1b[31m@unclosedtag\x1b[0m',
      '  \x1b[0m\x1b[34m│\x1b[0m   \x1b[0m\x1b[31m^^^^^^^^^^^^\x1b[0m \x1b[0m\x1b[31mUnknown tag\x1b[0m',
    ].join('\n');

    const result = parseMoonwaveOutput(input);

    expect(result).toHaveLength(1);
    expect(result[0].file).toBe('src/foo.lua');
    expect(result[0].line).toBe(3);
    expect(result[0].severity).toBe('error');
  });

  it('parses lerna-prefixed output', () => {
    const input = [
      '@quenty/acceltween: error: Unknown tag',
      '@quenty/acceltween:   ┌─ src/foo.lua:3:3',
      '@quenty/acceltween:   │',
    ].join('\n');

    const result = parseMoonwaveOutput(input);

    expect(result).toHaveLength(1);
    expect(result[0].file).toBe('src/acceltween/src/foo.lua');
  });

  it('skips the aborting summary line', () => {
    const input = [
      'error: Unknown tag',
      '  ┌─ src/foo.lua:3:3',
      '  │',
      '3 │   @unclosedtag',
      '  │   ^^^^^^^^^^^^ Unknown tag',
      '',
      'error: aborting due to diagnostic error',
    ].join('\n');

    const result = parseMoonwaveOutput(input);
    expect(result).toHaveLength(1);
  });

  it('returns empty array for clean JSON output', () => {
    const input = '[{"functions": [], "name": "FooClass"}]';
    const result = parseMoonwaveOutput(input);
    expect(result).toEqual([]);
  });

  it('returns empty array for empty input', () => {
    const result = parseMoonwaveOutput('');
    expect(result).toEqual([]);
  });
});
