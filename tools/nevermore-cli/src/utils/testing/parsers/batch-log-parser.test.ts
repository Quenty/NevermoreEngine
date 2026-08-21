import { describe, expect, it } from 'vitest';

import {
  countTracebacks,
  findSummaryEntries,
  parseBatchTestLogs,
} from './batch-log-parser.js';

const SLUG_MAP = new Map([['egghunt2026', 'egghunt2026']]);

function buildLogs(section: string): string {
  return [
    '===BATCH_TEST_BEGIN egghunt2026===',
    section,
    '===BATCH_TEST_END egghunt2026 PASS 1000===',
    '===BATCH_TEST_SUMMARY===',
    '[{"slug":"egghunt2026","success":true,"durationMs":1000}]',
  ].join('\n');
}

describe('parseBatchTestLogs', () => {
  it('reads test counts out of a package section', () => {
    const logs = buildLogs('Tests:  275 passed, 275 total');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.testCounts).toEqual({ passed: 275, failed: 0, total: 275 });
  });

  it('attributes a section closed by END when its BEGIN was dropped', () => {
    // Open Cloud keeps only the tail of a long run's log, so BEGIN — printed
    // first — is the first casualty while END and the summary survive.
    const logs = [
      '  ✓ some test that survived (3 ms)',
      'Tests:  275 passed, 275 total',
      '===BATCH_TEST_END egghunt2026 PASS 1000===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true,"durationMs":1000}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.success).toBe(true);
    expect(result?.testCounts).toEqual({ passed: 275, failed: 0, total: 275 });
  });

  it('does not let an out-of-order END steal another package’s output', () => {
    // The API does not deliver messages in order, so a stray END can arrive
    // mid-section. Only the first section can have lost its head; past that the
    // log is well-formed and a BEGIN-less END must not claim anything.
    const twoPackages = new Map([
      ['alpha', 'alpha'],
      ['beta', 'beta'],
    ]);
    const logs = [
      '===BATCH_TEST_BEGIN alpha===',
      'Tests:  10 passed, 10 total',
      '===BATCH_TEST_END beta PASS 5===',
      '===BATCH_TEST_END alpha PASS 10===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"alpha","success":true},{"slug":"beta","success":true}]',
    ].join('\n');

    const results = parseBatchTestLogs(logs, twoPackages);

    expect(results.get('alpha')?.testCounts?.total).toBe(10);
    // beta never had a section of its own; it must not inherit alpha's.
    expect(results.get('beta')?.testCounts).toBeUndefined();
    expect(results.get('beta')?.success).toBe(false);
  });

  it('fails a pass it cannot read, rather than trusting the pcall', () => {
    // No END marker either, so there is no boundary to attribute output with.
    // The pcall said success, but nothing here saw a test run.
    const logs = [
      'Tests:  275 passed, 275 total',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true,"durationMs":1000}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.success).toBe(false);
    expect(result?.error).toContain('no output could be attributed');
    expect(result?.testCounts).toBeUndefined();
  });

  it('still shows output it could not attribute', () => {
    // 330KB of real test output was being reported as "(no output)" because no
    // BEGIN marker survived to delimit it.
    const logs = [
      'PlayerBadgeHelper: attempt to index nil',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true,"durationMs":1000}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.logs).toContain('PlayerBadgeHelper');
  });

  it('closes a section whose END was delivered after the summary', () => {
    const logs = [
      '===BATCH_TEST_BEGIN egghunt2026===',
      'Tests:  1014 passed, 1077 total',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true,"durationMs":110467}]',
      '===BATCH_TEST_END egghunt2026 PASS 110467===',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.success).toBe(true);
    expect(result?.error).toBeUndefined();
    expect(result?.testCounts).toEqual({
      passed: 1014,
      failed: 0,
      total: 1077,
    });
  });

  it('keeps the summary payload out of the section it interrupts', () => {
    const logs = [
      '===BATCH_TEST_BEGIN egghunt2026===',
      'Tests:  10 passed, 10 total',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true},' +
        '{"slug":"other","success":false,"error":"boom"}]',
      '===BATCH_TEST_END egghunt2026 PASS 10===',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.logs).not.toContain('boom');
    expect(result?.success).toBe(true);
  });

  it('counts tracebacks that jest reports as a clean pass', () => {
    const logs = buildLogs(
      [
        'Tests:  155 passed, 155 total',
        'PlayerBadgeHelper: attempt to index nil',
        'Stack Begin',
        "Script 'PlayerBadgeHelper', Line 365",
        'Stack End',
      ].join('\n')
    );

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.testCounts?.failed).toBe(0);
    expect(result?.tracebackCount).toBe(1);
  });

  it('fails a section containing a traceback', () => {
    const logs = buildLogs(
      [
        'Tests:  155 passed, 155 total',
        'PlayerBadgeHelper: attempt to index nil',
        'Stack Begin',
        "Script 'PlayerBadgeHelper', Line 365",
        'Stack End',
      ].join('\n')
    );

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.success).toBe(false);
    expect(result?.error).toContain('Luau traceback(s)');
  });

  it('takes the whole inner string as the slug when END has no PASS or FAIL', () => {
    const logs = [
      '===BATCH_TEST_BEGIN egghunt2026===',
      'Tests:  5 passed, 5 total',
      '===BATCH_TEST_END egghunt2026===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.success).toBe(true);
    expect(result?.testCounts).toEqual({ passed: 5, failed: 0, total: 5 });
  });

  it('records no duration for an END that carries none', () => {
    const logs = [
      '===BATCH_TEST_BEGIN egghunt2026===',
      'Tests:  5 passed, 5 total',
      '===BATCH_TEST_END egghunt2026 PASS===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.durationMs).toBeUndefined();
  });

  it('falls back to the END marker duration when the summary entry omits one', () => {
    const logs = [
      '===BATCH_TEST_BEGIN egghunt2026===',
      'Tests:  5 passed, 5 total',
      '===BATCH_TEST_END egghunt2026 PASS 4242===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.durationMs).toBe(4242);
  });

  it('lets only the first BEGIN-less END claim the output above it', () => {
    const twoPackages = new Map([
      ['alpha', 'alpha'],
      ['beta', 'beta'],
    ]);
    const logs = [
      'Tests:  10 passed, 10 total',
      '===BATCH_TEST_END alpha PASS 10===',
      'Tests:  20 passed, 20 total',
      '===BATCH_TEST_END beta PASS 20===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"alpha","success":true},{"slug":"beta","success":true}]',
    ].join('\n');

    const results = parseBatchTestLogs(logs, twoPackages);

    expect(results.get('alpha')?.testCounts?.total).toBe(10);
    expect(results.get('beta')?.testCounts).toBeUndefined();
    expect(results.get('beta')?.logs).toBe('');
    expect(results.get('beta')?.error).toContain(
      'no output could be attributed'
    );
  });

  it('distinguishes a reported Luau error from an absent summary entry', () => {
    const twoPackages = new Map([
      ['alpha', 'alpha'],
      ['beta', 'beta'],
    ]);
    const logs = [
      '===BATCH_TEST_BEGIN alpha===',
      'Tests:  10 passed, 10 total',
      '===BATCH_TEST_END alpha FAIL 10===',
      '===BATCH_TEST_BEGIN beta===',
      'Tests:  20 passed, 20 total',
      '===BATCH_TEST_END beta PASS 20===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"alpha","success":false,"error":"boom"}]',
    ].join('\n');

    const results = parseBatchTestLogs(logs, twoPackages);

    expect(results.get('alpha')?.success).toBe(false);
    expect(results.get('alpha')?.error).toBe(
      'the batch runner reported a Luau error'
    );
    expect(results.get('beta')?.success).toBe(false);
    expect(results.get('beta')?.error).toBe(
      'this package is missing from the batch summary'
    );
  });

  it('reads every package as missing when the summary payload is not JSON', () => {
    const twoPackages = new Map([
      ['alpha', 'alpha'],
      ['beta', 'beta'],
    ]);
    const logs = [
      '===BATCH_TEST_BEGIN alpha===',
      'Tests:  10 passed, 10 total',
      '===BATCH_TEST_END alpha PASS 10===',
      '===BATCH_TEST_BEGIN beta===',
      'Tests:  20 passed, 20 total',
      '===BATCH_TEST_END beta PASS 20===',
      '===BATCH_TEST_SUMMARY===',
      'not json at all',
    ].join('\n');

    const results = parseBatchTestLogs(logs, twoPackages);

    expect(results.get('alpha')?.error).toBe(
      'this package is missing from the batch summary'
    );
    expect(results.get('beta')?.error).toBe(
      'this package is missing from the batch summary'
    );
  });

  it('reads every package as missing when no summary arrived at all', () => {
    const twoPackages = new Map([
      ['alpha', 'alpha'],
      ['beta', 'beta'],
    ]);
    const logs = [
      '===BATCH_TEST_BEGIN alpha===',
      'Tests:  10 passed, 10 total',
      '===BATCH_TEST_END alpha PASS 10===',
      '===BATCH_TEST_BEGIN beta===',
      'Tests:  20 passed, 20 total',
      '===BATCH_TEST_END beta PASS 20===',
    ].join('\n');

    const results = parseBatchTestLogs(logs, twoPackages);

    expect(results.get('alpha')?.error).toBe(
      'this package is missing from the batch summary'
    );
    expect(results.get('beta')?.error).toBe(
      'this package is missing from the batch summary'
    );
  });

  it('joins several failure reasons with a semicolon', () => {
    const logs = [
      '===BATCH_TEST_BEGIN egghunt2026===',
      'Tests:  2 failed, 8 passed, 10 total',
      'Test Suites:  1 failed, 3 total',
      '===BATCH_TEST_END egghunt2026 FAIL 10===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":false}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.error).toBe(
      'the batch runner reported a Luau error; ' +
        '1 test suite(s) failed; 2 test(s) failed'
    );
  });

  it('treats a marker missing its trailing delimiter as ordinary content', () => {
    const logs = [
      '===BATCH_TEST_BEGIN egghunt2026===',
      '===BATCH_TEST_BEGIN egghunt2026',
      'Tests:  5 passed, 5 total',
      '===BATCH_TEST_END egghunt2026 PASS 5===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.logs).toContain('===BATCH_TEST_BEGIN egghunt2026');
    expect(result?.testCounts).toEqual({ passed: 5, failed: 0, total: 5 });
  });

  it('hands unattributable output to the first package only', () => {
    const threePackages = new Map([
      ['alpha', 'alpha'],
      ['beta', 'beta'],
      ['gamma', 'gamma'],
    ]);
    const logs = [
      'PlayerBadgeHelper: attempt to index nil',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"alpha","success":true},{"slug":"beta","success":true},' +
        '{"slug":"gamma","success":true}]',
    ].join('\n');

    const results = parseBatchTestLogs(logs, threePackages);

    expect(results.get('alpha')?.logs).toContain('PlayerBadgeHelper');
    expect(results.get('beta')?.logs).toBe('');
    expect(results.get('gamma')?.logs).toBe('');
  });

  it('fails an empty section for having no jest report, with no counts', () => {
    const logs = [
      '===BATCH_TEST_BEGIN egghunt2026===',
      '===BATCH_TEST_END egghunt2026 PASS 0===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.success).toBe(false);
    expect(result?.logs).toBe('');
    expect(result?.error).toBe(
      'no jest report in output — nothing proves any test ran'
    );
    // No counts were seen, so none are reported — an empty section is not zero.
    expect(result?.testCounts).toBeUndefined();
  });
});

describe('findSummaryEntries', () => {
  it('finds the summary even when output landed after it', () => {
    // Messages are not delivered in order, so a stray line can follow the
    // summary. Treating the whole remainder as one JSON blob made the same
    // batch parse on one run and fail on the next.
    const lines = [
      '[{"slug":"alpha","success":true}]',
      '  ✓ a stray line that arrived late',
    ];

    expect(findSummaryEntries(lines, 0)).toEqual([
      { slug: 'alpha', success: true },
    ]);
  });

  it('returns undefined when there is no array to find', () => {
    expect(findSummaryEntries(['not json at all'], 0)).toBeUndefined();
  });
});

describe('countTracebacks', () => {
  it('counts each traceback separately', () => {
    expect(countTracebacks('Stack Begin\nfoo\nStack End\nStack Begin\n')).toBe(
      2
    );
  });

  it('is zero for empty output', () => {
    expect(countTracebacks('')).toBe(0);
  });
});
