import { describe, it, expect } from 'vitest';
import { parseSeleneOutput } from './selene-parser.js';

describe('parseSeleneOutput', () => {
  it('parses a warning with location', () => {
    const input = [
      'warning[unused_variable]: x is assigned a value, but never used',
      '  ┌─ src/foo.lua:1:7',
      '  │',
      '1 │ local x = 1',
      '  │       ^',
    ].join('\n');

    const result = parseSeleneOutput(input);

    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({
      file: 'src/foo.lua',
      line: 1,
      column: 7,
      severity: 'warning',
      message: 'x is assigned a value, but never used',
      title: 'selene(unused_variable)',
      source: 'selene',
    });
  });

  it('parses an error', () => {
    const input = [
      'error[undefined_variable]: x is not defined',
      '  ┌─ src/bar.lua:5:3',
      '  │',
      '5 │   print(x)',
      '  │         ^',
    ].join('\n');

    const result = parseSeleneOutput(input);

    expect(result).toHaveLength(1);
    expect(result[0].severity).toBe('error');
  });

  it('parses lerna-prefixed output', () => {
    const input = [
      '@quenty/acceltween: warning[unused_variable]: x is assigned a value, but never used',
      '@quenty/acceltween:   ┌─ src/foo.lua:1:7',
      '@quenty/acceltween:   │',
      '@quenty/acceltween: 1 │ local x = 1',
      '@quenty/acceltween:   │       ^',
    ].join('\n');

    const result = parseSeleneOutput(input);

    expect(result).toHaveLength(1);
    expect(result[0].file).toBe('src/acceltween/src/foo.lua');
    expect(result[0].severity).toBe('warning');
  });

  it('parses multiple diagnostics', () => {
    const input = [
      'warning[unused_variable]: unused is assigned a value, but never used',
      '  ┌─ src/foo.lua:1:7',
      '  │',
      '1 │ local unused = 1',
      '  │       ^^^^^^',
      '',
      'warning[unused_variable]: foo is defined, but never used',
      '  ┌─ src/foo.lua:2:16',
      '  │',
      '2 │ local function foo()',
      '  │                ^^^',
      '',
      'Results:',
      '0 errors',
      '2 warnings',
      '0 parse errors',
    ].join('\n');

    const result = parseSeleneOutput(input);
    expect(result).toHaveLength(2);
    expect(result[0].line).toBe(1);
    expect(result[1].line).toBe(2);
  });

  it('returns empty array for clean output', () => {
    const input = [
      'lerna notice cli v9.0.4',
      'lerna info versioning independent',
      'lerna success exec Executed command in 278 packages',
    ].join('\n');

    const result = parseSeleneOutput(input);
    expect(result).toEqual([]);
  });
});
