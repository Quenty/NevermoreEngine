/**
 * Unit tests for format-output utilities.
 */

import { describe, it, expect } from 'vitest';
import { resolveMode } from './format-output.js';

describe('resolveMode', () => {
  it('returns json when format is json', () => {
    expect(resolveMode({ format: 'json' })).toBe('json');
  });

  it('returns text when format is text', () => {
    expect(resolveMode({ format: 'text' })).toBe('text');
  });

  it('returns base64 when format is base64', () => {
    expect(resolveMode({ format: 'base64' })).toBe('base64');
  });

  it('returns table when TTY and no format specified', () => {
    expect(resolveMode({ isTTY: true })).toBe('table');
  });

  it('returns text when non-TTY and no format specified', () => {
    expect(resolveMode({ isTTY: false })).toBe('text');
  });

  it('format flag overrides TTY detection', () => {
    expect(resolveMode({ format: 'json', isTTY: true })).toBe('json');
    expect(resolveMode({ format: 'text', isTTY: true })).toBe('text');
  });
});
