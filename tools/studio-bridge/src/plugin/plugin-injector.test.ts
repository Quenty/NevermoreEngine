import { describe, it, expect } from 'vitest';
import { substituteTemplate } from '@quenty/nevermore-template-helpers';

describe('substituteTemplate', () => {
  const template = [
    'local PORT = "{{PORT}}"',
    'local SESSION_ID = "{{SESSION_ID}}"',
  ].join('\n');

  it('replaces all placeholders', () => {
    const result = substituteTemplate(template, {
      PORT: '12345',
      SESSION_ID: 'abc-def',
    });

    expect(result).toContain('local PORT = "12345"');
    expect(result).toContain('local SESSION_ID = "abc-def"');
  });

  it('replaces multiple occurrences of the same placeholder', () => {
    const tmpl = '{{PORT}} and {{PORT}} again';
    const result = substituteTemplate(tmpl, {
      PORT: '8080',
    });
    expect(result).toBe('8080 and 8080 again');
  });

  it('does not HTML-escape special characters', () => {
    const tmpl = '{{VALUE}}';
    const result = substituteTemplate(tmpl, {
      VALUE: 'a & b < c > d',
    });
    expect(result).toBe('a & b < c > d');
  });
});
