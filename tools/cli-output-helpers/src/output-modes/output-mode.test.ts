import { describe, it, expect } from 'vitest';
import { resolveOutputMode } from './output-mode.js';

describe('resolveOutputMode', () => {
  it('returns json when json flag is true regardless of TTY', () => {
    expect(resolveOutputMode({ json: true, isTTY: true })).toBe('json');
    expect(resolveOutputMode({ json: true, isTTY: false })).toBe('json');
  });

  it('returns json when envOverride is json', () => {
    expect(resolveOutputMode({ envOverride: 'json' })).toBe('json');
  });

  it('returns text when envOverride is text', () => {
    expect(resolveOutputMode({ envOverride: 'text' })).toBe('text');
  });

  it('returns text when isTTY is false without json', () => {
    expect(resolveOutputMode({ isTTY: false })).toBe('text');
  });

  it('returns table when isTTY is true without json', () => {
    expect(resolveOutputMode({ isTTY: true })).toBe('table');
  });

  it('returns table by default with no options', () => {
    expect(resolveOutputMode({})).toBe('table');
  });
});
