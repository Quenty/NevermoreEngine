import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { type DeployTarget } from '@quenty/nevermore-deploy';

import { mergeFailureReasons, runSingleTestAsync } from './test-runner.js';
import { TEST_RESULTS_FORMAT } from '../structured-test-results.js';
import {
  type Deployment,
  type JobContext,
  type ScriptRunResult,
} from '../../job-context/job-context.js';

const PASSING_LOGS = [
  'Test Suites: 3 passed, 3 total',
  'Tests:       25 passed, 25 total',
].join('\n');

function structuredResults(overrides: Record<string, unknown> = {}) {
  return {
    format: TEST_RESULTS_FORMAT,
    success: true,
    ranJest: true,
    passed: 25,
    failed: 0,
    skipped: 0,
    total: 25,
    suitesPassed: 3,
    suitesFailed: 0,
    suitesTotal: 3,
    failures: [],
    omittedFailures: 0,
    ...overrides,
  };
}

/**
 * A context that runs nothing: it hands back the run result and logs the test
 * wants to reason about. Everything else is the minimum the runner touches.
 */
function createContext(run: ScriptRunResult, logs: string): JobContext {
  return {
    buildPlaceAsync: async (options) => ({
      rbxlPath: 'unused.rbxl',
      target: options.target,
    }),
    deployBuiltPlaceAsync: async () => ({} as Deployment),
    runScriptAsync: async () => run,
    getLogsAsync: async () => logs,
    releaseAsync: async () => {},
    releaseBuiltPlaceAsync: async () => {},
    disposeAsync: async () => {},
  };
}

describe('runSingleTestAsync', () => {
  let packagePath: string;

  beforeAll(async () => {
    packagePath = await fs.mkdtemp(path.join(os.tmpdir(), 'nevermore-test-'));
    await fs.writeFile(
      path.join(packagePath, 'ServerMain.server.lua'),
      'return nil\n'
    );
  });

  afterAll(async () => {
    await fs.rm(packagePath, { recursive: true, force: true });
  });

  async function runAsync(run: ScriptRunResult, logs: string) {
    return runSingleTestAsync(createContext(run, logs), {
      packagePath,
      packageName: 'maid',
      target: {
        scriptTemplate: 'ServerMain.server.lua',
      } as unknown as DeployTarget,
    });
  }

  it('fails a run whose returned results say it failed', async () => {
    // The runner used to announce this by throwing, which failed the task. Now
    // it returns the verdict, and these logs are what a truncated window leaves
    // behind: a jest report from a suite that passed and no sign of the one
    // that did not.
    const result = await runAsync(
      {
        success: true,
        returnValues: [structuredResults({ success: false, failed: 2 })],
      },
      PASSING_LOGS
    );

    expect(result.success).toBe(false);
    expect(result.error).toContain('2 test(s) failed');
  });

  it('reports the counts the run returned, not the ones in the log', async () => {
    const result = await runAsync(
      {
        success: true,
        returnValues: [structuredResults({ passed: 400, total: 400 })],
      },
      PASSING_LOGS
    );

    expect(result.success).toBe(true);
    expect(result.testCounts).toEqual({ passed: 400, failed: 0, total: 400 });
  });

  it('accepts returned results as proof the runner ran', async () => {
    // Demanding a jest report in the logs is a stand-in for that proof, and it
    // is the first thing a truncated log window costs.
    const result = await runAsync(
      { success: true, returnValues: [structuredResults()] },
      '(logs truncated)'
    );

    expect(result.success).toBe(true);
  });

  it('still fails a run with a traceback in its logs', async () => {
    // Jest cannot count a deferred-callback crash, so passing results are no
    // reason to stop reading the logs.
    const result = await runAsync(
      { success: true, returnValues: [structuredResults()] },
      `${PASSING_LOGS}\nStack Begin\nScript 'maid.spec', Line 4\nStack End`
    );

    expect(result.success).toBe(false);
  });

  it('falls back to the logs for a script that returned nothing', async () => {
    // A test script written before results were returned. It must keep working,
    // and it must not start passing when its logs say otherwise.
    const failing = await runAsync(
      { success: true, returnValues: [] },
      'Tests:       2 failed, 23 passed, 25 total'
    );
    expect(failing.success).toBe(false);
    expect(failing.error).toContain('2 test(s) failed');

    const passing = await runAsync(
      { success: true, returnValues: [] },
      PASSING_LOGS
    );
    expect(passing.success).toBe(true);
    expect(passing.testCounts).toEqual({ passed: 25, failed: 0, total: 25 });
  });

  it('fails a script that returned nothing and logged nothing', async () => {
    const result = await runAsync(
      { success: true, returnValues: undefined },
      ''
    );

    expect(result.success).toBe(false);
    expect(result.error).toContain('nothing proves any test ran');
  });
});

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
