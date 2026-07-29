import { describe, expect, it } from 'vitest';

import { countTracebacks, parseBatchTestLogs } from './batch-log-parser.js';

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
