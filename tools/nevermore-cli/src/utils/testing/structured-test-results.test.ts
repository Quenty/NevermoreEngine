/**
 * Unit tests for decoding the results a test run returns. The decoder stands
 * between a transport and a pass/fail verdict, so the cases that matter are the
 * ones where a value is not what it claims to be.
 */

import { describe, expect, it } from 'vitest';

import {
  TEST_RESULTS_FORMAT,
  decodeStructuredTestResults,
  describeUnexplainedVerdict,
  findStructuredTestResults,
  structuredFailureReasons,
  toParsedTestCounts,
} from './structured-test-results.js';

function results(overrides: Record<string, unknown> = {}) {
  return {
    format: TEST_RESULTS_FORMAT,
    success: true,
    ranJest: true,
    passed: 25,
    failed: 0,
    skipped: 1,
    total: 26,
    suitesPassed: 3,
    suitesFailed: 0,
    suitesTotal: 3,
    failures: [],
    omittedFailures: 0,
    ...overrides,
  };
}

describe('decodeStructuredTestResults', () => {
  it('decodes a results table', () => {
    const decoded = decodeStructuredTestResults(results());

    expect(decoded).toEqual({
      success: true,
      ranJest: true,
      passed: 25,
      failed: 0,
      skipped: 1,
      total: 26,
      suitesPassed: 3,
      suitesFailed: 0,
      suitesTotal: 3,
      failures: [],
      omittedFailures: 0,
      error: undefined,
    });
  });

  it('ignores a value that is not tagged as results', () => {
    // A probe run (--script-text) returns whatever it likes, and none of it is
    // a verdict on anything.
    expect(decodeStructuredTestResults({ success: true })).toBeUndefined();
    expect(
      decodeStructuredTestResults({ format: 'something-else', success: true })
    ).toBeUndefined();
    expect(
      decodeStructuredTestResults('nevermore-test-results@1')
    ).toBeUndefined();
    expect(decodeStructuredTestResults(undefined)).toBeUndefined();
    expect(decodeStructuredTestResults([results()])).toBeUndefined();
  });

  it('reads only an explicit true as a pass', () => {
    // Anything else means the verdict did not survive the trip, and a lost
    // verdict must not read as a passing one.
    expect(
      decodeStructuredTestResults(results({ success: 'yes' }))?.success
    ).toBe(false);
    expect(
      decodeStructuredTestResults(results({ success: undefined }))?.success
    ).toBe(false);
  });

  it('treats a malformed count as zero rather than as a number', () => {
    const decoded = decodeStructuredTestResults(
      results({ passed: 'lots', total: null, failed: Number.NaN })
    );

    expect(decoded?.passed).toBe(0);
    expect(decoded?.total).toBe(0);
    expect(decoded?.failed).toBe(0);
  });

  it('keeps only well-formed failures', () => {
    const decoded = decodeStructuredTestResults(
      results({
        failures: [
          { name: 'Maid does a thing', message: 'expected true' },
          { name: 'Maid does another thing' },
          { message: 'no name' },
          'not a failure',
        ],
      })
    );

    expect(decoded?.failures).toEqual([
      { name: 'Maid does a thing', message: 'expected true' },
      { name: 'Maid does another thing', message: undefined },
    ]);
  });

  it('accepts an empty failure list however the transport spelled it', () => {
    // An empty Lua table marshals as an array on the bridge and can arrive as an
    // object from the cloud.
    expect(
      decodeStructuredTestResults(results({ failures: {} }))?.failures
    ).toEqual([]);
  });
});

describe('findStructuredTestResults', () => {
  it('finds results among other returned values', () => {
    const found = findStructuredTestResults([
      42,
      'log',
      results({ passed: 9 }),
    ]);

    expect(found?.passed).toBe(9);
  });

  it('is undefined when the script returned nothing', () => {
    // A test script written before this convention returns nil, which is the
    // case that has to keep falling back to the logs.
    expect(findStructuredTestResults([])).toBeUndefined();
    expect(findStructuredTestResults(undefined)).toBeUndefined();
  });
});

describe('structuredFailureReasons', () => {
  it('says nothing about a passing run', () => {
    expect(
      structuredFailureReasons(decodeStructuredTestResults(results())!)
    ).toEqual([]);
  });

  it('words counts the way the log parser does, so the overlap merges', () => {
    const reasons = structuredFailureReasons(
      decodeStructuredTestResults(
        results({ success: false, failed: 2, suitesFailed: 1 })
      )!
    );

    expect(reasons).toContain('2 test(s) failed');
    expect(reasons).toContain('1 test suite(s) failed');
  });

  it('explains a failure no count can account for', () => {
    const reasons = structuredFailureReasons(
      decodeStructuredTestResults(results({ success: false }))!
    );

    expect(reasons).toEqual(['the test runner reported the run as failed']);
  });

  it('carries the message the runner supplied', () => {
    const reasons = structuredFailureReasons(
      decodeStructuredTestResults(
        results({
          success: false,
          error: '[NevermoreTestRunner] Jest run failed',
        })
      )!
    );

    expect(reasons).toContain('[NevermoreTestRunner] Jest run failed');
  });
});

describe('structuredFailureReasons wording', () => {
  it('never builds a reason out of zeros', () => {
    // "0 test(s) and 0 test suite(s) failed" was a real failure reason once. A
    // reason saying nothing failed is unreadable as either verdict, and it is
    // what made the bug behind it hard to see.
    for (const overrides of [
      { success: false },
      { success: false, failed: 0, suitesFailed: 0 },
      {
        success: false,
        error: '[NevermoreTestRunner] the run was interrupted',
      },
    ]) {
      const reasons = structuredFailureReasons(
        decodeStructuredTestResults(results(overrides))!
      );

      expect(reasons.length).toBeGreaterThan(0);
      for (const reason of reasons) {
        expect(reason).not.toMatch(/\b0 test\(s\)/);
        expect(reason).not.toMatch(/\b0 test suite\(s\)/);
      }
    }
  });

  it('does not restate the counts the reasons already carry', () => {
    const reasons = structuredFailureReasons(
      decodeStructuredTestResults(
        results({
          success: false,
          failed: 2,
          suitesFailed: 1,
          error:
            '[NevermoreTestRunner] 2 test(s) failed, 1 test suite(s) failed',
        })
      )!
    );

    expect(reasons).toEqual(['1 test suite(s) failed', '2 test(s) failed']);
  });
});

describe('describeUnexplainedVerdict', () => {
  it('is silent about a passing run', () => {
    // The direction that broke: a fully passing result must read as a pass and
    // raise nothing at all.
    expect(
      describeUnexplainedVerdict(decodeStructuredTestResults(results())!)
    ).toBeUndefined();
  });

  it('is silent about a failure its counts explain', () => {
    expect(
      describeUnexplainedVerdict(
        decodeStructuredTestResults(results({ success: false, failed: 2 }))!
      )
    ).toBeUndefined();
    expect(
      describeUnexplainedVerdict(
        decodeStructuredTestResults(
          results({ success: false, suitesFailed: 1 })
        )!
      )
    ).toBeUndefined();
  });

  it('describes a failure no count supports', () => {
    // The exact signature of a runner reading the wrong field: plausible counts,
    // and every package failed anyway.
    const description = describeUnexplainedVerdict(
      decodeStructuredTestResults(
        results({ success: false, passed: 311, failed: 0, total: 311 })
      )!
    );

    expect(description).toContain('nothing failed');
    expect(description).toContain('311 passed');
  });
});

describe('toParsedTestCounts', () => {
  it('narrows to the counts the reporters render', () => {
    expect(toParsedTestCounts(decodeStructuredTestResults(results())!)).toEqual(
      {
        passed: 25,
        failed: 0,
        total: 26,
      }
    );
  });
});
