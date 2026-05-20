import { describe, it, expect, afterEach } from 'vitest';
import { OutputHelper } from './outputHelper.js';

describe('OutputHelper.formatErrorChain', () => {
  const originalVerbose = OutputHelper.isVerbose();

  afterEach(() => {
    OutputHelper.setVerbose(originalVerbose);
  });

  it('returns String(value) for non-Error inputs', () => {
    expect(OutputHelper.formatErrorChain('boom')).toBe('boom');
    expect(OutputHelper.formatErrorChain(42)).toBe('42');
    expect(OutputHelper.formatErrorChain(null)).toBe('null');
  });

  it('returns just the message for a bare Error in non-verbose mode', () => {
    OutputHelper.setVerbose(false);
    expect(OutputHelper.formatErrorChain(new Error('nope'))).toBe('nope');
  });

  it('walks .cause chain (the undici fetch-failed case)', () => {
    OutputHelper.setVerbose(false);
    const cause = new Error('ECONNRESET');
    const err = new Error('fetch failed', { cause });
    expect(OutputHelper.formatErrorChain(err)).toBe(
      'fetch failed\n  caused by: ECONNRESET'
    );
  });

  it('walks multiple nested causes', () => {
    OutputHelper.setVerbose(false);
    const inner = new Error('socket hang up');
    const mid = new Error('Connect Timeout Error', { cause: inner });
    const outer = new Error('fetch failed', { cause: mid });
    expect(OutputHelper.formatErrorChain(outer)).toBe(
      'fetch failed\n  caused by: Connect Timeout Error\n  caused by: socket hang up'
    );
  });

  it('stops at non-Error cause values', () => {
    OutputHelper.setVerbose(false);
    const err = new Error('outer', { cause: 'plain string' });
    expect(OutputHelper.formatErrorChain(err)).toBe('outer');
  });

  it('does not loop on self-referential cause cycles', () => {
    OutputHelper.setVerbose(false);
    const a: Error & { cause?: unknown } = new Error('a');
    const b: Error & { cause?: unknown } = new Error('b');
    a.cause = b;
    b.cause = a;
    expect(OutputHelper.formatErrorChain(a)).toBe('a\n  caused by: b');
  });

  it('first line stays the head message so summarizeError-style trimming still works', () => {
    OutputHelper.setVerbose(false);
    const err = new Error('fetch failed', { cause: new Error('whatever') });
    const firstLine = OutputHelper.formatErrorChain(err).split('\n')[0];
    expect(firstLine).toBe('fetch failed');
  });

  it('appends the stack in verbose mode', () => {
    OutputHelper.setVerbose(true);
    const err = new Error('boom');
    const out = OutputHelper.formatErrorChain(err);
    expect(out.startsWith('boom\n')).toBe(true);
    expect(out).toContain(err.stack!);
  });
});
