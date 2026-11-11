import { describe, expect, it } from 'vitest';

import { evaluateTestOutcome, hasTestReport } from './test-log-parser.js';

describe('evaluateTestOutcome', () => {
  it('passes a clean jest report', () => {
    const outcome = evaluateTestOutcome('Tests: 275 passed, 275 total', {
      requireTestReport: true,
    });

    expect(outcome.success).toBe(true);
    expect(outcome.failureReasons).toEqual([]);
  });

  it('refuses to pass output with no jest report in it', () => {
    // Absence of failure was previously read as success, so an empty log passed.
    const outcome = evaluateTestOutcome('some unrelated chatter', {
      requireTestReport: true,
    });

    expect(outcome.success).toBe(false);
    expect(outcome.failureReasons.join()).toContain('no jest report');
  });

  it('exempts probe runs, which have no jest in them at all', () => {
    const outcome = evaluateTestOutcome('hello from a probe script');

    expect(outcome.success).toBe(true);
  });

  it('fails on a traceback even when every test passed', () => {
    // Jest cannot see a deferred-callback crash: it fires outside any test.
    const logs = [
      'Tests: 155 passed, 155 total',
      'attempt to index nil',
      'Stack Begin',
      "Script 'ServerScriptService.egghunt2026.Foo', Line 12",
      'Stack End',
    ].join('\n');

    const outcome = evaluateTestOutcome(logs, { requireTestReport: true });

    expect(outcome.success).toBe(false);
    expect(outcome.failureReasons.join()).toContain('traceback');
  });

  it('reports every reason a run failed, not just the first', () => {
    const logs = [
      'Tests: 19 failed, 470 passed, 516 total',
      'Stack Begin',
      "Script 'ServerScriptService.egghunt2026.Foo', Line 12",
      'Stack End',
    ].join('\n');

    const outcome = evaluateTestOutcome(logs, { requireTestReport: true });

    expect(outcome.failureReasons).toHaveLength(2);
  });
});

describe('hasTestReport', () => {
  it('accepts a runner that ran and found nothing', () => {
    // Packages without specs are legitimate; passWithNoTests depends on this.
    expect(hasTestReport('No tests found, exiting with code 0')).toBe(true);
  });

  it('rejects silence', () => {
    expect(hasTestReport('')).toBe(false);
  });
});
