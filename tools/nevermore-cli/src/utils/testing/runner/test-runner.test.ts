import { describe, expect, it } from 'vitest';

import { mergeFailureReasons } from './test-runner.js';

describe('mergeFailureReasons', () => {
  it('does not repeat reasons the context already reported', () => {
    // Batch mode evaluates the same logs upstream, so both sources describe the
    // same failures. Concatenating them read as double the failures.
    const merged = mergeFailureReasons(
      '3 test suite(s) failed; 19 test(s) failed',
      ['3 test suite(s) failed', '19 test(s) failed']
    );

    expect(merged).toEqual(['3 test suite(s) failed', '19 test(s) failed']);
  });

  it('keeps reasons only one side knows about', () => {
    const merged = mergeFailureReasons(
      'the batch runner reported a Luau error',
      ['19 test(s) failed']
    );

    expect(merged).toHaveLength(2);
  });

  it('is empty when nothing failed', () => {
    expect(mergeFailureReasons(undefined, [])).toEqual([]);
  });
});
