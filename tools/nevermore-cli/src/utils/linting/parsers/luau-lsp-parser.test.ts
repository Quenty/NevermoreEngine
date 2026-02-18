import { describe, it, expect } from 'vitest';
import { parseLuauLspOutput } from './luau-lsp-parser.js';

describe('parseLuauLspOutput', () => {
  it('parses a TypeError line', () => {
    const input =
      "src/foo/Bar.lua(10,5): TypeError: Expected this to be 'string', but got 'number'";
    const result = parseLuauLspOutput(input);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      file: 'src/foo/Bar.lua',
      line: 10,
      column: 5,
      severity: 'error',
      message: "Expected this to be 'string', but got 'number'",
      title: 'luau-lsp(TypeError)',
      source: 'luau-lsp',
    });
  });

  it('classifies LocalUnused as warning', () => {
    const input =
      "src/bar.lua(2,7): LocalUnused: Variable 'y' is never used; prefix with '_' to silence";
    const result = parseLuauLspOutput(input);

    expect(result).toHaveLength(1);
    expect(result[0].severity).toBe('warning');
    expect(result[0].title).toBe('luau-lsp(LocalUnused)');
  });

  it('handles relative paths with ../', () => {
    const input =
      "../../tmp/test.lua(1,1): TypeError: Expected this to be 'string', but got 'number'";
    const result = parseLuauLspOutput(input);

    expect(result).toHaveLength(1);
    expect(result[0].file).toBe('../../tmp/test.lua');
  });

  it('parses multiple lines', () => {
    const input = [
      "src/a.lua(1,1): TypeError: type mismatch",
      "src/b.lua(5,3): LocalUnused: Variable 'x' is never used; prefix with '_' to silence",
      '',
      '> some other output line',
    ].join('\n');

    const result = parseLuauLspOutput(input);
    expect(result).toHaveLength(2);
    expect(result[0].severity).toBe('error');
    expect(result[1].severity).toBe('warning');
  });

  it('returns empty array for clean output', () => {
    const result = parseLuauLspOutput('');
    expect(result).toEqual([]);
  });

  it('skips non-matching lines', () => {
    const input = [
      '> lint:luau',
      '> luau-lsp analyze ...',
      '',
    ].join('\n');

    const result = parseLuauLspOutput(input);
    expect(result).toEqual([]);
  });
});
