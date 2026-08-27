/**
 * Unit tests for BatchScriptJobContext's handle plumbing — the wrapper hands
 * each package a BatchDeployment of its own, so anything it forwards to the
 * inner context has to be unwrapped first.
 */

import { describe, it, expect, vi } from 'vitest';
import { BatchScriptJobContext } from './batch-script-job-context.js';
import { type Deployment, type JobContext } from './job-context.js';
import { type LogFetchStats } from '../testing/log-fetch-stats.js';

const STATS: LogFetchStats = {
  requests: 1,
  pages: 1,
  entries: 1,
  messages: 3665,
  chars: 272909,
};

describe('BatchScriptJobContext.getLogFetchStats', () => {
  it('asks the inner context about the deployment that did the fetch', () => {
    // The stats live on the shared deployment the batch ran on. Forwarding the
    // BatchDeployment reads a field that is not on it and reports "no fetch
    // stats" for a fetch that did happen — while the batch parser, which is
    // handed the inner handle directly, reports the real numbers in the same
    // message.
    const sharedDeployment = {} as Deployment;
    const getLogFetchStats = vi.fn(
      (deployment: Deployment): LogFetchStats | undefined =>
        deployment === sharedDeployment ? STATS : undefined
    );
    const inner = { getLogFetchStats } as unknown as JobContext;

    const context = new BatchScriptJobContext(inner, []);
    const batchDeployment = {
      packageName: 'gameconfig',
      inner: sharedDeployment,
    } as unknown as Deployment;

    expect(context.getLogFetchStats(batchDeployment)).toEqual(STATS);
    expect(getLogFetchStats).toHaveBeenCalledWith(sharedDeployment);
  });

  it('reports nothing when the inner context cannot measure a fetch', () => {
    // A local batch reads its logs off the Studio bridge, which counts no
    // requests. Absent stays absent rather than becoming zeroes.
    const inner = {} as unknown as JobContext;
    const context = new BatchScriptJobContext(inner, []);

    expect(
      context.getLogFetchStats({
        packageName: 'x',
        inner: {},
      } as unknown as Deployment)
    ).toBeUndefined();
  });
});
