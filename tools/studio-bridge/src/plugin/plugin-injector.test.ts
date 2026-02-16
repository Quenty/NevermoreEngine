import { describe, it, expect } from 'vitest';
import { substituteTemplate, escapeLuaString } from './plugin-injector.js';

describe('substituteTemplate', () => {
  const template = [
    'local PORT = "{{PORT}}"',
    'local SESSION_ID = "{{SESSION_ID}}"',
  ].join('\n');

  it('replaces all placeholders', () => {
    const result = substituteTemplate(template, {
      port: '12345',
      sessionId: 'abc-def',
    });

    expect(result).toContain('local PORT = "12345"');
    expect(result).toContain('local SESSION_ID = "abc-def"');
  });

  it('replaces multiple occurrences of the same placeholder', () => {
    const tmpl = '{{PORT}} and {{PORT}} again';
    const result = substituteTemplate(tmpl, {
      port: '8080',
      sessionId: 'x',
    });
    expect(result).toBe('8080 and 8080 again');
  });
});

describe('escapeLuaString', () => {
  it('escapes backslashes', () => {
    expect(escapeLuaString('path\\to\\file')).toBe('path\\\\to\\\\file');
  });

  it('escapes double quotes', () => {
    expect(escapeLuaString('say "hello"')).toBe('say \\"hello\\"');
  });

  it('escapes newlines', () => {
    expect(escapeLuaString('line1\nline2')).toBe('line1\\nline2');
  });

  it('escapes carriage returns', () => {
    expect(escapeLuaString('line1\r\nline2')).toBe('line1\\r\\nline2');
  });

  it('escapes null bytes', () => {
    expect(escapeLuaString('before\0after')).toBe('before\\0after');
  });

  it('handles empty string', () => {
    expect(escapeLuaString('')).toBe('');
  });

  it('handles string with no special characters', () => {
    expect(escapeLuaString('hello world 123')).toBe('hello world 123');
  });

  it('handles combined escapes', () => {
    const input = 'local x = "foo\\bar"\nprint(x)';
    const result = escapeLuaString(input);
    expect(result).toBe('local x = \\"foo\\\\bar\\"\\nprint(x)');
  });
});
