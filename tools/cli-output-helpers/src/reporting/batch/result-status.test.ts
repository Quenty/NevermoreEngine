import { describe, it, expect } from 'vitest';
import {
  formatStatusText,
  resolveResultStatus,
  statusIcon,
  tallyCaveats,
  type ResultStatusInput,
} from './result-status.js';

function counts(passed: number, total: number): ResultStatusInput {
  return {
    success: true,
    progressSummary: {
      kind: 'test-counts',
      passed,
      failed: total - passed,
      total,
    },
  };
}

describe('resolveResultStatus', () => {
  it('calls a clean pass a success', () => {
    const status = resolveResultStatus(counts(68, 68));

    expect(status.severity).toBe('success');
    expect(formatStatusText(status)).toBe('Passed (68/68)');
  });

  it('keeps a failure a failure however it is qualified', () => {
    // A caveat narrows what a result proves; it never softens a failure into a
    // warning, or a red row would go amber for having lost its logs.
    const status = resolveResultStatus({
      ...counts(3, 4),
      success: false,
      caveats: ['logs-lost'],
    });

    expect(status.severity).toBe('failure');
    expect(formatStatusText(status)).toBe('FAILED (3/4) - logs lost');
  });

  it('demotes a pass that carries a caveat to a warning', () => {
    const status = resolveResultStatus({
      ...counts(35, 35),
      caveats: ['logs-lost'],
    });

    expect(status.severity).toBe('warning');
    expect(formatStatusText(status)).toBe('Passed (35/35) - logs lost');
  });

  it('flags a pass that ran no tests', () => {
    const status = resolveResultStatus(counts(0, 0));

    expect(status.severity).toBe('warning');
    expect(status.caveats).toEqual(['empty-run']);
  });

  it('calls a pass with no counts unverified, when counts were expected', () => {
    // The claim being avoided: a green row with nothing behind it is
    // indistinguishable from one that tested something.
    const status = resolveResultStatus(
      { success: true },
      { expectsTestCounts: true }
    );

    expect(status.severity).toBe('warning');
    expect(formatStatusText(status)).toBe(
      'Unverified - no test counts reported'
    );
  });

  it('says nothing about missing counts where none were expected', () => {
    // A deploy has no test counts and is not suspect for lacking them.
    const status = resolveResultStatus({ success: true });

    expect(status.severity).toBe('success');
    expect(status.caveats).toEqual([]);
  });

  it('reports every caveat that applies, not just the first', () => {
    const status = resolveResultStatus(
      { ...counts(0, 0), caveats: ['logs-lost'] },
      { expectsTestCounts: true }
    );

    expect(status.caveats).toEqual(['logs-lost', 'empty-run']);
    expect(formatStatusText(status)).toBe(
      'Passed (0/0) - logs lost, ran 0 tests'
    );
  });

  it('names the phase a failure happened in', () => {
    const status = resolveResultStatus({
      success: false,
      failedPhase: 'uploading',
    });

    expect(formatStatusText(status)).toBe('FAILED at uploading');
  });

  it('takes the labels the caller uses for its own kind of run', () => {
    const status = resolveResultStatus(
      { success: true },
      { successLabel: 'Deployed' }
    );

    expect(formatStatusText(status)).toBe('Deployed');
  });
});

describe('tallyCaveats', () => {
  it('counts each caveat across a run', () => {
    const statuses = [
      resolveResultStatus({ ...counts(5, 5), caveats: ['logs-lost'] }),
      resolveResultStatus({ ...counts(9, 9), caveats: ['logs-lost'] }),
      resolveResultStatus(counts(0, 0)),
    ];

    expect(tallyCaveats(statuses)).toEqual([
      {
        caveat: 'logs-lost',
        count: 2,
        message: expect.stringContaining('2 package(s) lost their log output'),
      },
      {
        caveat: 'empty-run',
        count: 1,
        message: '1 package(s) ran 0 tests — check test discovery',
      },
    ]);
  });

  it('says nothing when every result is clean', () => {
    expect(tallyCaveats([resolveResultStatus(counts(3, 3))])).toEqual([]);
  });
});

describe('statusIcon', () => {
  it('uses emoji for markdown and single-width glyphs for a terminal', () => {
    // A variation-selector emoji is two columns wide, which breaks the aligned
    // status column in the summary table.
    expect(statusIcon('warning', 'emoji')).toBe('⚠️');
    expect(statusIcon('warning', 'ascii')).toBe('⚠');
    expect(statusIcon('success', 'ascii')).toBe('✓');
    expect(statusIcon('failure', 'ascii')).toBe('✗');
  });
});
