/**
 * Unit tests for the local contexts, over a fake Studio session: that a run
 * hands its script return values on as a ScriptRunResult, that a run which
 * never completed reports none rather than an empty result, and that every
 * session the context opened is ended.
 */

import { describe, it, expect, vi } from 'vitest';
import { type Reporter } from '@quenty/cli-output-helpers/reporting';
import { LocalJobContext, LocalPlaceJobContext } from './local-job-context.js';
import { type BuiltPlace } from './job-context.js';
import {
  type StudioScriptResult,
  type StudioScriptSession,
  type StudioSessionFactory,
} from './studio-session.js';

function createReporter(): Reporter {
  return {
    onPackagePhaseChange: vi.fn(),
    onPackageProgressUpdate: vi.fn(),
    onPackageStart: vi.fn(),
    onPackageResult: vi.fn(),
  } as unknown as Reporter;
}

const BUILT_PLACE = {
  rbxlPath: '/tmp/build.rbxl',
  target: {},
} as unknown as BuiltPlace;

function createStudio(executeAsync: () => Promise<StudioScriptResult>) {
  const session: StudioScriptSession = {
    executeAsync: vi.fn(executeAsync),
    endAsync: vi.fn(async () => {}),
  };
  const studio: StudioSessionFactory<StudioScriptSession> = {
    startSessionAsync: vi.fn(async ({ onPhase }) => {
      onPhase?.('launching');
      return session;
    }),
  };
  return { session, studio };
}

async function deployAsync(executeAsync: () => Promise<StudioScriptResult>) {
  const reporter = createReporter();
  const { session, studio } = createStudio(executeAsync);
  const context = new LocalJobContext({ reporter, studio });
  const deployment = await context.deployBuiltPlaceAsync({
    builtPlace: BUILT_PLACE,
    packageName: 'maid',
    packagePath: '/repo/src/maid',
  });
  return { context, deployment, session, studio, reporter };
}

describe('LocalJobContext.runScriptAsync', () => {
  it('reports the values the script returned', async () => {
    const { context, deployment } = await deployAsync(async () => ({
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
    expect((await context.getLogsAsync(deployment)).text).toBe('ran');
  });

  it('leaves returnValues absent when the session reported none', async () => {
    const { context, deployment } = await deployAsync(async () => ({
      success: false,
      logs: '[StudioBridge] Timed out after 200ms',
    }));

    const result = await context.runScriptAsync(deployment, {
      scriptContent: 'while true do end',
      packageName: 'maid',
    });

    expect(result.returnValues).toBeUndefined();
  });

  it('leaves returnValues absent when the session throws', async () => {
    const { context, deployment } = await deployAsync(async () => {
      throw new Error('no connected client');
    });

    const result = await context.runScriptAsync(deployment, {
      scriptContent: 'return results',
      packageName: 'maid',
    });

    expect(result.success).toBe(false);
    expect(result.returnValues).toBeUndefined();
    expect((await context.getLogsAsync(deployment)).text).toContain(
      'no connected client'
    );
  });
});

describe('LocalPlaceJobContext', () => {
  it('opens the built place and reports the session phases', async () => {
    const { studio, reporter } = await deployAsync(async () => ({
      success: true,
      logs: '',
    }));

    expect(studio.startSessionAsync).toHaveBeenCalledWith(
      expect.objectContaining({ placePath: '/tmp/build.rbxl' })
    );
    expect(reporter.onPackagePhaseChange).toHaveBeenCalledWith(
      'maid',
      'launching'
    );
  });

  it('ends a released session once, and any left over on dispose', async () => {
    const { studio } = createStudio(async () => ({ success: true, logs: '' }));
    const context = new LocalPlaceJobContext({
      reporter: createReporter(),
      studio,
    });
    const deploy = () =>
      context.deployBuiltPlaceAsync({
        builtPlace: BUILT_PLACE,
        packageName: 'maid',
        packagePath: '/repo/src/maid',
      });

    const released = await deploy();
    await context.releaseAsync(released);
    await context.releaseAsync(released);
    expect(released.session.endAsync).toHaveBeenCalledTimes(1);

    await deploy();
    await context.disposeAsync();
    expect(released.session.endAsync).toHaveBeenCalledTimes(2);
  });
});
