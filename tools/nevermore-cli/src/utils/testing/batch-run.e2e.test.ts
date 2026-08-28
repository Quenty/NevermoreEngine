/**
 * End-to-end test for one aggregated batch run.
 *
 * Every piece of this path has unit tests — the parser, the renderer, the job
 * context — and none of them cover the thing that actually goes wrong, which is
 * the seams between them. What a reader sees is produced by a log travelling
 * through all three, and until the execution returned data rather than printing
 * it, that could not be asserted on without spying on `console.log`.
 *
 * So this drives the whole path from the one end that is not ours: a transport
 * handing back the messages a real Open Cloud task produces, complete with the
 * message types, the multi-line error and the trailing JSON summary. Everything
 * downstream is the real code, and the assertions are on what a person would
 * read and on what each package's result came out as.
 */

import { describe, it, expect, vi } from 'vitest';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { BatchScriptJobContext } from '../job-context/batch-script-job-context.js';
import {
  type BuiltPlace,
  type Deployment,
  type JobContext,
  type JobLogs,
  type RunScriptOptions,
  type ScriptRunResult,
} from '../job-context/job-context.js';
import { type TaskLogMessage } from '../open-cloud/open-cloud-client.js';
import { type BatchTarget } from '../batch/changed-packages-utils.js';
import { renderBatchOutcome } from './parsers/batch-log-renderer.js';

const { SLUG_MAP } = vi.hoisted(() => ({
  SLUG_MAP: new Map([
    ['@quenty/alpha', 'alpha'],
    ['@quenty/beta', 'beta'],
  ]),
}));

// The only mocked collaborator: building the combined place shells out to rojo
// and lune, which is a different subject from what this test is about. What it
// produces that matters downstream is the slug map.
vi.mock('./runner/combined-project-generator.js', () => ({
  generateCombinedProjectAsync: vi.fn(async () => ({
    rbxlPath: '/tmp/batch.rbxl',
    slugMap: SLUG_MAP,
    primaryTarget: { placeId: 1, universeId: 2 },
    buildContext: { cleanupAsync: async () => {} },
  })),
}));

/**
 * The summary the Luau runner prints last and also returns.
 *
 * `counts` are present for both packages: the runner reads them off what the
 * test script returned, or off what NevermoreTestRunnerUtils left in its state
 * module when the script returned nothing.
 */
const SUMMARY_ENTRIES = [
  {
    slug: 'alpha',
    success: true,
    durationMs: 1500,
    counts: {
      passed: 68,
      failed: 0,
      skipped: 0,
      total: 68,
      suitesPassed: 4,
      suitesFailed: 0,
      suitesTotal: 4,
    },
    ranJest: true,
  },
  {
    slug: 'beta',
    success: false,
    durationMs: 900,
    error: 'beta had a failing suite',
    counts: {
      passed: 3,
      failed: 1,
      skipped: 0,
      total: 4,
      suitesPassed: 0,
      suitesFailed: 1,
      suitesTotal: 1,
    },
    ranJest: true,
  },
];

const SUMMARY_JSON = JSON.stringify(SUMMARY_ENTRIES);

/**
 * What the task printed, in the shape Open Cloud delivers it: typed messages,
 * one of which carries a whole traceback, and none of which are guaranteed to
 * fall inside a package's section.
 */
const TASK_MESSAGES: TaskLogMessage[] = [
  { message: '[BatchTest] running 2 packages', messageType: 'OUTPUT' },
  { message: '===BATCH_TEST_BEGIN alpha===', messageType: 'OUTPUT' },
  {
    message: 'PASS ServerScriptService.alpha.Thing.spec',
    messageType: 'OUTPUT',
  },
  { message: '===BATCH_TEST_END alpha PASS 1500===', messageType: 'OUTPUT' },
  {
    message:
      "TaskScript:12: a leaked task exploded\nStack Begin\nScript 'Foo', Line 3\nStack End",
    messageType: 'ERROR',
  },
  { message: '===BATCH_TEST_BEGIN beta===', messageType: 'OUTPUT' },
  {
    message: '[BatchTest] beta: beta had a failing suite',
    messageType: 'WARNING',
  },
  { message: '===BATCH_TEST_END beta FAIL 900===', messageType: 'OUTPUT' },
  { message: '===BATCH_TEST_SUMMARY===', messageType: 'OUTPUT' },
  { message: SUMMARY_JSON, messageType: 'OUTPUT' },
];

/** A transport that runs nothing and reports the messages it was handed. */
class FakeTransport implements JobContext {
  public scriptContent?: string;
  public deployCount = 0;
  public runCount = 0;

  constructor(
    private readonly _messages: TaskLogMessage[],
    private readonly _returnValues?: unknown[]
  ) {}

  async buildPlaceAsync(): Promise<BuiltPlace> {
    throw new Error('the batch context builds the combined place itself');
  }

  async deployBuiltPlaceAsync(): Promise<Deployment> {
    this.deployCount++;
    return {};
  }

  async runScriptAsync(
    _deployment: Deployment,
    options: RunScriptOptions
  ): Promise<ScriptRunResult> {
    this.runCount++;
    this.scriptContent = options.scriptContent;
    return {
      success: true,
      taskState: 'COMPLETE',
      returnValues: this._returnValues,
    };
  }

  async getLogsAsync(): Promise<JobLogs> {
    const text = this._messages.map((m) => m.message).join('\n');
    return {
      text,
      messages: this._messages,
      stats: {
        requests: 1,
        pages: 1,
        entries: 1,
        messages: this._messages.length,
        chars: text.length,
      },
    };
  }

  async releaseAsync(): Promise<void> {}
  async releaseBuiltPlaceAsync(): Promise<void> {}
  async disposeAsync(): Promise<void> {}
}

function createBatch(
  messages: TaskLogMessage[] = TASK_MESSAGES,
  returnValues?: unknown[]
) {
  const targets = [...SLUG_MAP.keys()].map((name) => ({
    name,
    packageName: name,
    path: `/repo/src/${name.split('/')[1]}`,
    target: { placeId: 1, universeId: 2 },
    places: [],
  })) as unknown as BatchTarget[];

  const transport = new FakeTransport(messages, returnValues);
  const batch = new BatchScriptJobContext(transport, targets, {
    repoRoot: '/repo',
  });

  return { batch, transport, targets };
}

/** What the per-package loop asks the context for, for one package. */
async function runPackageAsync(
  batch: BatchScriptJobContext,
  packageName: string
): Promise<ScriptRunResult> {
  const deployment = await batch.deployBuiltPlaceAsync({
    builtPlace: { rbxlPath: '/tmp/batch.rbxl', target: {} } as BuiltPlace,
    packageName,
    packagePath: '/repo',
  });

  return batch.runScriptAsync(deployment, {
    scriptContent: '',
    packageName,
  });
}

describe('an aggregated batch run, end to end', () => {
  it('renders the whole run: every line, in order, grouped and titled', async () => {
    const { batch } = createBatch();

    const outcome = await batch.getExecutionOutcomeAsync();
    const rendered = renderBatchOutcome(outcome, {
      useGroups: true,
      color: false,
    });

    expect(rendered).toEqual([
      // Before any package began, so it belongs to none of them.
      '[BatchTest] running 2 packages',
      '::group::@quenty/alpha - ✅ Passed (68/68) (1.5s)',
      'PASS ServerScriptService.alpha.Thing.spec',
      '::endgroup::',
      // Between two packages. This is the output the parser used to discard,
      // and the only trace of a crash that belongs to no section.
      'TaskScript:12: a leaked task exploded',
      'Stack Begin',
      "Script 'Foo', Line 3",
      'Stack End',
      '::group::@quenty/beta - ❌ FAILED (3/4) (900ms)',
      '[BatchTest] beta: beta had a failing suite',
      'beta had a failing suite',
      '::endgroup::',
      // The summary marker and its payload are framing, not output.
    ]);
  });

  it('colors by the severity the transport reported, jest output untouched', async () => {
    const { batch } = createBatch();

    const outcome = await batch.getExecutionOutcomeAsync();
    const rendered = renderBatchOutcome(outcome, {
      useGroups: false,
      color: true,
    });

    expect(rendered).toContain(
      OutputHelper.formatError('TaskScript:12: a leaked task exploded')
    );
    expect(rendered).toContain(
      OutputHelper.formatWarning('[BatchTest] beta: beta had a failing suite')
    );
    expect(rendered).toContain('PASS ServerScriptService.alpha.Thing.spec');
  });

  it('gives each package its own verdict, counts and duration', async () => {
    const { batch } = createBatch();

    const alpha = await runPackageAsync(batch, '@quenty/alpha');
    const beta = await runPackageAsync(batch, '@quenty/beta');

    expect(alpha.success).toBe(true);
    expect(alpha.durationMs).toBe(1500);
    expect(alpha.testResults).toMatchObject({
      passed: 68,
      failed: 0,
      total: 68,
    });

    expect(beta.success).toBe(false);
    expect(beta.durationMs).toBe(900);
    expect(beta.errorMessage).toContain('beta had a failing suite');
    expect(beta.testResults).toMatchObject({ passed: 3, failed: 1, total: 4 });
  });

  it('builds, uploads and executes once for the whole batch', async () => {
    const { batch, transport } = createBatch();

    await batch.getExecutionOutcomeAsync();
    await runPackageAsync(batch, '@quenty/alpha');
    await runPackageAsync(batch, '@quenty/beta');

    expect(transport.deployCount).toBe(1);
    expect(transport.runCount).toBe(1);
    // The script the packages ran is the template with this batch's slugs in
    // it — the one substitution the context makes, and nothing runs if it is
    // wrong.
    expect(transport.scriptContent).toContain('["alpha","beta"]');
    expect(transport.scriptContent).not.toContain('{{ PACKAGE_SLUGS_JSON }}');
  });

  it('judges a package whose whole section the log window dropped', async () => {
    // The case this path exists for. beta printed nothing that survived — no
    // BEGIN, no END, no jest report — so before the summary came back as a
    // return value it was failed for having no attributable output, and
    // rendered nothing at all: no group, no verdict, no reason.
    const { batch } = createBatch(
      [
        { message: '===BATCH_TEST_BEGIN alpha===', messageType: 'OUTPUT' },
        {
          message: 'PASS ServerScriptService.alpha.Thing.spec',
          messageType: 'OUTPUT',
        },
        {
          message: '===BATCH_TEST_END alpha PASS 1500===',
          messageType: 'OUTPUT',
        },
      ],
      [SUMMARY_ENTRIES]
    );

    const outcome = await batch.getExecutionOutcomeAsync();
    const beta = outcome.results.get('@quenty/beta');

    expect(beta?.testCounts).toEqual({ passed: 3, failed: 1, total: 4 });
    expect(beta?.countsSource).toBe('returned');
    expect(beta?.logsLost).toBe(true);
    // Not failed for the absence of a section, which is what used to happen.
    expect(beta?.error).not.toContain('no output could be attributed');

    const rendered = renderBatchOutcome(outcome, {
      useGroups: true,
      color: false,
    });

    expect(rendered).toContain(
      '::group::@quenty/beta - ❌ FAILED (3/4) - Logs lost (900ms)'
    );
    expect(rendered.join('\n')).toContain('survived the run');
  });

  it('marks a pass judged on counts alone as one, rather than an ordinary pass', async () => {
    // Trustworthy counts, but nothing to check for tracebacks against and
    // nothing to read if someone goes looking, so it does not get to look like
    // every other green package in the list.
    const { batch } = createBatch(
      [{ message: 'nothing survived', messageType: 'OUTPUT' }],
      [
        [
          {
            slug: 'alpha',
            success: true,
            durationMs: 1200,
            counts: {
              passed: 35,
              failed: 0,
              skipped: 0,
              total: 35,
              suitesPassed: 2,
              suitesFailed: 0,
              suitesTotal: 2,
            },
            ranJest: true,
          },
        ],
      ]
    );

    const outcome = await batch.getExecutionOutcomeAsync();

    expect(outcome.results.get('@quenty/alpha')?.success).toBe(true);
    expect(
      renderBatchOutcome(outcome, { useGroups: true, color: false })
    ).toContain(
      '::group::@quenty/alpha - ⚠️ Passed (35/35) - Logs lost (1.2s)'
    );
  });

  it('prefers the returned summary over the printed one', async () => {
    // Both channels carry the same summary. The returned one is read because it
    // is the copy the engine's log buffer cannot truncate — so when they
    // disagree, which only happens if the printed one arrived damaged, the
    // returned one wins.
    const { batch } = createBatch(TASK_MESSAGES, [
      [
        {
          slug: 'alpha',
          success: true,
          durationMs: 4200,
          counts: {
            passed: 99,
            failed: 0,
            skipped: 0,
            total: 99,
            suitesPassed: 1,
            suitesFailed: 0,
            suitesTotal: 1,
          },
          ranJest: true,
        },
      ],
    ]);

    const alpha = (await batch.getExecutionOutcomeAsync()).results.get(
      '@quenty/alpha'
    );

    expect(alpha?.testCounts?.total).toBe(99);
    expect(alpha?.durationMs).toBe(4200);
  });

  it('reports what reading the log turned up without printing it', async () => {
    // A log window that dropped everything but the summary: the run is still
    // judged, and the shortfall is handed back as a diagnostic for the command
    // to place after the output rather than printed from inside the transport.
    const { batch } = createBatch([
      { message: '===BATCH_TEST_SUMMARY===', messageType: 'OUTPUT' },
      { message: SUMMARY_JSON, messageType: 'OUTPUT' },
    ]);

    const outcome = await batch.getExecutionOutcomeAsync();

    expect(outcome.diagnostics.length).toBeGreaterThan(0);
    expect(outcome.diagnostics.map((d) => d.message).join('\n')).toContain(
      'could not attribute any of it to a package section'
    );
    // Still counted, because the counts came back in the summary rather than
    // being scraped out of the section that went missing.
    expect(outcome.results.get('@quenty/alpha')?.testCounts?.total).toBe(68);
  });
});
