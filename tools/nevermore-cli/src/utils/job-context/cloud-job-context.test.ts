/**
 * Unit tests for CloudJobContext.runScriptAsync — validates what a finished
 * Open Cloud task reports back as a ScriptRunResult, in particular that a task
 * which produced no output stays distinguishable from one that returned nothing.
 */

import { describe, it, expect, vi, afterEach } from 'vitest';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import { CloudJobContext } from './cloud-job-context.js';
import {
  type LuauTask,
  type OpenCloudClient,
} from '../open-cloud/open-cloud-client.js';
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
 * A client whose task completes as `completedTask`. The real deployment handle
 * is private to the context, so the test passes the three fields runScriptAsync
 * reads off it.
 */
function createContext(completedTask: Partial<LuauTask>) {
  const task = {
    path: 'universes/1/places/2/versions/3/luau-execution-session-tasks/4',
    createTime: '2026-01-01T00:00:00Z',
    updateTime: '2026-01-01T00:01:00Z',
    user: 'users/1',
    state: 'COMPLETE',
    script: 'return 1',
    ...completedTask,
  } as LuauTask;

  const client = {
    createExecutionTaskAsync: vi.fn(async () => task),
    pollTaskCompletionAsync: vi.fn(async () => task),
  } as unknown as OpenCloudClient;

  const context = new CloudJobContext(createReporter(), client);
  const deployment = {
    universeId: 1,
    placeId: 2,
    version: 3,
  } as unknown as Deployment;

  return { context, deployment };
}

describe('CloudJobContext.runScriptAsync', () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it('reports the values the script returned', async () => {
    // Fake timers keep the client-side timeout race from leaving a live timer
    // behind; nothing in the run itself waits on one.
    vi.useFakeTimers();
    const { context, deployment } = createContext({
      state: 'COMPLETE',
      output: { results: [{ slug: 'maid', counts: { passed: 1014 } }] },
    });

    const result = await context.runScriptAsync(deployment, {
      scriptContent: 'return results',
      packageName: 'maid',
    });

    expect(result.success).toBe(true);
    expect(result.returnValues).toEqual([
      { slug: 'maid', counts: { passed: 1014 } },
    ]);
  });

  it('reports an empty result when the task returned nothing', async () => {
    vi.useFakeTimers();
    const { context, deployment } = createContext({
      state: 'COMPLETE',
      output: {},
    });

    const result = await context.runScriptAsync(deployment, {
      scriptContent: 'print("hi")',
      packageName: 'maid',
    });

    expect(result.returnValues).toEqual([]);
  });

  it('leaves returnValues absent when a failed task carried no output', async () => {
    vi.useFakeTimers();
    const { context, deployment } = createContext({
      state: 'FAILED',
      output: undefined,
    });

    const result = await context.runScriptAsync(deployment, {
      scriptContent: 'return huge',
      packageName: 'maid',
    });

    expect(result.success).toBe(false);
    expect(result.taskState).toBe('FAILED');
    expect(result.returnValues).toBeUndefined();
  });
});
