import { describe, it, expect, afterEach } from 'vitest';
import { formatJson } from './json-formatter.js';

describe('formatJson', () => {
  const originalIsTTY = process.stdout.isTTY;

  afterEach(() => {
    process.stdout.isTTY = originalIsTTY;
  });

  it('pretty-prints with indentation when pretty: true', () => {
    const result = formatJson({ a: 1, b: [2, 3] }, { pretty: true });
    expect(result).toBe(JSON.stringify({ a: 1, b: [2, 3] }, null, 2));
    expect(result).toContain('\n');
  });

  it('emits compact single-line JSON when pretty: false', () => {
    const result = formatJson({ a: 1, b: [2, 3] }, { pretty: false });
    expect(result).toBe('{"a":1,"b":[2,3]}');
    expect(result).not.toContain('\n');
  });

  it('explicit pretty: true overrides non-TTY', () => {
    process.stdout.isTTY = undefined as any;
    const result = formatJson({ x: 1 }, { pretty: true });
    expect(result).toContain('\n');
  });

  it('explicit pretty: false overrides TTY', () => {
    process.stdout.isTTY = true;
    const result = formatJson({ x: 1 }, { pretty: false });
    expect(result).not.toContain('\n');
  });
});
