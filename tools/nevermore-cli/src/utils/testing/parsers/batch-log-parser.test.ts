import { afterEach, describe, expect, it, vi } from 'vitest';
import { OutputHelper } from '@quenty/cli-output-helpers';

import {
  countTracebacks,
  findSummaryEntries,
  parseBatchTestLogs,
} from './batch-log-parser.js';

/** Collect what the parser said out loud, so silence can be asserted on. */
function captureWarnings(): () => string[] {
  const warnings: string[] = [];
  vi.spyOn(OutputHelper, 'warn').mockImplementation((message: string) => {
    warnings.push(message);
  });
  vi.spyOn(OutputHelper, 'info').mockImplementation(() => {});
  return () => warnings;
}

afterEach(() => {
  vi.restoreAllMocks();
});

const RETURNED_COUNTS =
  '"counts":{"passed":273,"failed":2,"skipped":1,"total":276,' +
  '"suitesPassed":8,"suitesFailed":1,"suitesTotal":9},"ranJest":true';

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

  it('prefers the counts the runner returned over the ones in the section', () => {
    // The whole point of returning them: these are the numbers a truncated log
    // window cannot take away.
    const logs = [
      '===BATCH_TEST_BEGIN egghunt2026===',
      '(the section this run printed is gone)',
      '===BATCH_TEST_END egghunt2026 PASS 1000===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true,"durationMs":1000,"counts":' +
        '{"passed":275,"failed":0,"skipped":2,"total":277,' +
        '"suitesPassed":9,"suitesFailed":0,"suitesTotal":9}}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.testCounts).toEqual({ passed: 275, failed: 0, total: 277 });
  });

  it('ignores malformed counts instead of reporting zeroes', () => {
    const logs = buildLogs('Tests:  275 passed, 275 total').replace(
      '"durationMs":1000',
      '"durationMs":1000,"counts":{"passed":"lots"}'
    );

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.testCounts).toEqual({ passed: 275, failed: 0, total: 275 });
  });

  it('reports why the runner failed a package rather than guessing', () => {
    // A failing suite used to reach here as a Luau error. It arrives as a
    // verdict now, and saying "Luau error" about it sends you hunting for one.
    const logs = [
      '===BATCH_TEST_BEGIN egghunt2026===',
      'Tests:  2 failed, 273 passed, 275 total',
      '===BATCH_TEST_END egghunt2026 FAIL 1000===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":false,"durationMs":1000,' +
        '"error":"[NevermoreTestRunner] 2 test(s) and 0 test suite(s) failed",' +
        '"counts":{"passed":273,"failed":2,"skipped":0,"total":275,' +
        '"suitesPassed":8,"suitesFailed":0,"suitesTotal":9}}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.success).toBe(false);
    expect(result?.error).toContain('[NevermoreTestRunner] 2 test(s)');
    expect(result?.error).not.toContain('Luau error');
    expect(result?.testCounts).toEqual({ passed: 273, failed: 2, total: 275 });
  });

  it('does not believe a pass reported alongside failed tests', () => {
    const logs = [
      '===BATCH_TEST_BEGIN egghunt2026===',
      'Tests:  275 passed, 275 total',
      '===BATCH_TEST_END egghunt2026 PASS 1000===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":true,"durationMs":1000,"counts":' +
        '{"passed":273,"failed":2,"skipped":0,"total":275,' +
        '"suitesPassed":8,"suitesFailed":1,"suitesTotal":9}}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    expect(result?.success).toBe(false);
    expect(result?.error).toContain('2 failed test(s)');
  });

  it('still reads a summary from a package that returned no counts', () => {
    // A test script written before results were returned.
    const result = parseBatchTestLogs(
      buildLogs('Tests:  275 passed, 275 total'),
      SLUG_MAP
    ).get('egghunt2026');

    expect(result?.success).toBe(true);
    expect(result?.testCounts).toEqual({ passed: 275, failed: 0, total: 275 });
  });

  it('records where each package’s counts came from', () => {
    // The structured channel and log scraping produce identical-looking output,
    // so a channel that quietly stopped flowing is invisible without this.
    const scraped = parseBatchTestLogs(
      buildLogs('Tests:  275 passed, 275 total'),
      SLUG_MAP
    ).get('egghunt2026');
    expect(scraped?.countsSource).toBe('scraped');
    expect(scraped?.testResults).toBeUndefined();

    const returned = parseBatchTestLogs(
      buildLogs('Tests:  2 failed, 273 passed, 276 total').replace(
        '"durationMs":1000',
        `"durationMs":1000,${RETURNED_COUNTS}`
      ),
      SLUG_MAP
    ).get('egghunt2026');
    expect(returned?.countsSource).toBe('returned');
    expect(returned?.testResults).toMatchObject({
      ranJest: true,
      passed: 273,
      failed: 2,
      skipped: 1,
      total: 276,
      suitesFailed: 1,
    });
  });

  it('warns out loud when a package fell back to log scraping', () => {
    const warnings = captureWarnings();

    parseBatchTestLogs(buildLogs('Tests:  275 passed, 275 total'), SLUG_MAP);

    expect(
      warnings().some(
        (w) =>
          w.includes('returned no test results') && w.includes('egghunt2026')
      )
    ).toBe(true);
  });

  it('says nothing about a fallback when every package returned its counts', () => {
    const warnings = captureWarnings();

    parseBatchTestLogs(
      buildLogs('Tests:  2 failed, 273 passed, 276 total').replace(
        '"durationMs":1000',
        `"durationMs":1000,${RETURNED_COUNTS}`
      ),
      SLUG_MAP
    );

    expect(warnings().some((w) => w.includes('returned no test results'))).toBe(
      false
    );
  });

  it('passes every package whose returned counts are clean', () => {
    // The regression this guards: a runner consulted jest-lua's inverted
    // AggregatedResult.success and failed all four packages in a batch, three of
    // which had every test passing.
    const warnings = captureWarnings();
    const fourPackages = new Map([
      ['access', 'access'],
      ['animations', 'animations'],
      ['binder', 'binder'],
      ['blend', 'blend'],
    ]);

    const clean = (slug: string, passed: number) =>
      [
        `===BATCH_TEST_BEGIN ${slug}===`,
        `Tests:  ${passed} passed, ${passed} total`,
        `===BATCH_TEST_END ${slug} PASS 100===`,
      ].join('\n');

    const entry = (slug: string, passed: number) =>
      `{"slug":"${slug}","success":true,"durationMs":100,"ranJest":true,` +
      `"counts":{"passed":${passed},"failed":0,"skipped":0,"total":${passed},` +
      `"suitesPassed":1,"suitesFailed":0,"suitesTotal":1}}`;

    const logs = [
      clean('access', 311),
      clean('animations', 8),
      clean('binder', 99),
      clean('blend', 3),
      '===BATCH_TEST_SUMMARY===',
      `[${entry('access', 311)},${entry('animations', 8)},` +
        `${entry('binder', 99)},${entry('blend', 3)}]`,
    ].join('\n');

    const parsed = parseBatchTestLogs(logs, fourPackages);

    expect([...parsed.values()].filter((r) => r.success)).toHaveLength(4);
    expect(parsed.get('access')?.testCounts).toEqual({
      passed: 311,
      failed: 0,
      total: 311,
    });
    expect(warnings()).toHaveLength(0);
  });

  it('warns when a failure’s own counts show nothing failed', () => {
    const warnings = captureWarnings();

    const logs = [
      '===BATCH_TEST_BEGIN egghunt2026===',
      'Tests:  311 passed, 311 total',
      '===BATCH_TEST_END egghunt2026 FAIL 100===',
      '===BATCH_TEST_SUMMARY===',
      '[{"slug":"egghunt2026","success":false,"durationMs":100,"ranJest":true,' +
        '"error":"[NevermoreTestRunner] something","counts":{"passed":311,' +
        '"failed":0,"skipped":0,"total":311,"suitesPassed":19,"suitesFailed":0,' +
        '"suitesTotal":19}}]',
    ].join('\n');

    const result = parseBatchTestLogs(logs, SLUG_MAP).get('egghunt2026');

    // The verdict stands — it is not the parser's to overturn — but it is loud.
    expect(result?.success).toBe(false);
    expect(
      warnings().some((w) => w.includes('own counts show nothing failed'))
    ).toBe(true);
  });

  it('warns when the returned counts and the log disagree', () => {
    // The exact failure that shipped once: the runner read the wrong level of
    // jest's result, so every count came back zero and read as a clean run.
    const warnings = captureWarnings();

    const result = parseBatchTestLogs(
      buildLogs('Tests:  275 passed, 275 total').replace(
        '"durationMs":1000',
        '"durationMs":1000,"counts":{"passed":0,"failed":0,"skipped":0,' +
          '"total":0,"suitesPassed":0,"suitesFailed":0,"suitesTotal":0},"ranJest":true'
      ),
      SLUG_MAP
    );

    expect(
      warnings().some((w) =>
        w.includes('returned counts disagree with the log')
      )
    ).toBe(true);
    expect(result.get('egghunt2026')?.countsSource).toBe('returned');
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
