/**
 * Unit tests for LocalJobContext.runScriptAsync — validates that a bridge run
 * hands its script return values on as a ScriptRunResult, and that a run which
 * never completed reports none rather than an empty result.
 */

import { describe, it, expect, vi } from 'vitest';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import { LocalJobContext } from './local-job-context.js';
import { type Deployment } from './job-context.js';

function createReporter(): Reporter {
  return {
    onPackagePhaseChange: vi.fn(),
    onPackageProgressUpdate: vi.fn(),
    onPackageStart: vi.fn(),
    onPackageResult: vi.fn(),
  } as unknown as Reporter;
}

/**
 * The deployment handle is private to the context, so the test stands in a
 * bridge with the one method runScriptAsync calls on it.
 */
function createDeployment(
  executeAsync: () => Promise<{
    success: boolean;
    logs: string;
    returnValues?: unknown[];
  }>
): Deployment {
  return {
    bridge: { executeAsync },
    cachedLogs: '',
  } as unknown as Deployment;
}

describe('LocalJobContext.runScriptAsync', () => {
  it('reports the values the script returned', async () => {
    const context = new LocalJobContext(createReporter());
    const deployment = createDeployment(async () => ({
      success: true,
      logs: 'ran',
      returnValues: [{ counts: { passed: 7 } }],
    }));

    const result = await context.runScriptAsync(deployment, {
      scriptContent: 'return results',
      packageName: 'maid',
    });

    expect(result.success).toBe(true);
    expect(result.returnValues).toEqual([{ counts: { passed: 7 } }]);
    expect(await context.getLogsAsync(deployment)).toBe('ran');
  });

  it('leaves returnValues absent when the bridge reported none', async () => {
    const context = new LocalJobContext(createReporter());
    const deployment = createDeployment(async () => ({
      success: false,
      logs: '[StudioBridge] Timed out after 200ms',
    }));

    const result = await context.runScriptAsync(deployment, {
      scriptContent: 'while true do end',
      packageName: 'maid',
    });

    expect(result.returnValues).toBeUndefined();
  });

  it('leaves returnValues absent when the bridge throws', async () => {
    const context = new LocalJobContext(createReporter());
    const deployment = createDeployment(async () => {
      throw new Error('no connected client');
    });

    const result = await context.runScriptAsync(deployment, {
      scriptContent: 'return results',
      packageName: 'maid',
    });

    expect(result.success).toBe(false);
    expect(result.returnValues).toBeUndefined();
    expect(await context.getLogsAsync(deployment)).toContain(
      'no connected client'
    );
  });
});
