import { describe, expect, it } from 'vitest';

import { formatResultStatus } from './formatting.js';
import { type PackageResult } from '../reporter.js';

function buildResult(overrides: Partial<PackageResult> = {}): PackageResult {
  return {
    packageName: 'egghunt2026',
    success: true,
    logs: '',
    durationMs: 1000,
    ...overrides,
  } as PackageResult;
}

describe('formatResultStatus', () => {
  it('shows a pass with its test counts', () => {
    const status = formatResultStatus(
      buildResult({
        progressSummary: {
          kind: 'test-counts',
          passed: 275,
          failed: 0,
          total: 275,
        },
      }),
      'Passed',
      'Failed',
      true
    );

    expect(status).toContain('✅');
    expect(status).toContain('275');
  });

  it('refuses to render a pass when no test counts came back', () => {
    // A green check with nothing behind it reads identically to a real result,
    // which is how an empty log becomes an uninformative ✅.
    const status = formatResultStatus(buildResult(), 'Passed', 'Failed', true);

    expect(status).not.toContain('✅');
    expect(status).toContain('⚠️');
    expect(status).toContain('Unverified');
  });

  it('still warns when the runner reported zero tests', () => {
    const status = formatResultStatus(
      buildResult({
        progressSummary: {
          kind: 'test-counts',
          passed: 0,
          failed: 0,
          total: 0,
        },
      }),
      'Passed',
      'Failed',
      true
    );

    expect(status).toContain('⚠️');
  });

  it('leaves non-test results alone', () => {
    const status = formatResultStatus(
      buildResult({ progressSummary: { kind: 'version', version: 325 } }),
      'Deployed',
      'Failed'
    );

    expect(status).toContain('✅');
  });
});
