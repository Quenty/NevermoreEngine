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

  it('reports no test counts when the section output was lost', () => {
    // The summary prints last, so it survives a fetch that dropped everything
    // above it. The pcall said success, but nothing here saw a test run.
    const logs = [
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true,"durationMs":1000}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.testCounts).toBeUndefined();
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
