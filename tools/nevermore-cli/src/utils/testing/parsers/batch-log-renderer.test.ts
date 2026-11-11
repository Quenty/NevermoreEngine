import { describe, it, expect } from 'vitest';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  renderBatchLog,
  toRenderableLines,
  type RenderableLogLine,
} from './batch-log-renderer.js';
import { type BatchPackageResult } from './batch-log-parser.js';

const SLUGS = new Map([
  ['alpha', '@quenty/alpha'],
  ['beta', '@quenty/beta'],
]);

/** Plain OUTPUT lines, which is what most of a run is. */
function plain(...lines: string[]): RenderableLogLine[] {
  return lines.map((line) => ({ line, severity: 'output' as const }));
}

function render(
  lines: RenderableLogLine[],
  results?: Map<string, BatchPackageResult>
): string[] {
  return renderBatchLog(lines, {
    slugToPackage: SLUGS,
    results,
    useGroups: true,
    color: false,
  });
}

function result(over: Partial<BatchPackageResult>): BatchPackageResult {
  return {
    slug: 'alpha',
    success: true,
    logs: '',
    tracebackCount: 0,
    ...over,
  };
}

describe('renderBatchLog', () => {
  it('wraps each package section in a group of its own', () => {
    const out = render(
      plain(
        '===BATCH_TEST_BEGIN alpha===',
        'alpha ran',
        '===BATCH_TEST_END alpha PASS 10==='
      )
    );

    expect(out).toEqual([
      '::group::@quenty/alpha',
      'alpha ran',
      '::endgroup::',
    ]);
  });

  it('keeps output that belongs to no package, outside any group', () => {
    // The whole point. Output between two sections used to be discarded by the
    // parser, so a crash landing between packages reached nobody.
    const out = render(
      plain(
        'harness starting up',
        '===BATCH_TEST_BEGIN alpha===',
        'alpha ran',
        '===BATCH_TEST_END alpha PASS 10===',
        'something exploded between packages',
        '===BATCH_TEST_BEGIN beta===',
        'beta ran',
        '===BATCH_TEST_END beta PASS 20===',
        'trailing note after the last package'
      )
    );

    expect(out).toEqual([
      'harness starting up',
      '::group::@quenty/alpha',
      'alpha ran',
      '::endgroup::',
      'something exploded between packages',
      '::group::@quenty/beta',
      'beta ran',
      '::endgroup::',
      'trailing note after the last package',
    ]);
  });

  it('emits one group per package rather than one per start', () => {
    // The bug this replaces: every package was grouped when it started, which
    // in an aggregated batch is all of them at once, before the task existed.
    const out = render(
      plain(
        '===BATCH_TEST_BEGIN alpha===',
        '===BATCH_TEST_END alpha PASS 10===',
        '===BATCH_TEST_BEGIN beta===',
        '===BATCH_TEST_END beta PASS 20==='
      )
    );

    expect(out.filter((line) => line === '::endgroup::')).toHaveLength(2);
    expect(out.indexOf('::group::@quenty/beta')).toBeGreaterThan(
      out.indexOf('::endgroup::')
    );
  });

  it('closes a section left open by a missing END', () => {
    // Groups must balance whatever the log did, or every later line renders
    // inside a package it has nothing to do with.
    const out = render(
      plain(
        '===BATCH_TEST_BEGIN alpha===',
        'alpha ran',
        '===BATCH_TEST_BEGIN beta===',
        'beta ran',
        '===BATCH_TEST_END beta PASS 20==='
      )
    );

    expect(out.filter((line) => line.startsWith('::group::'))).toHaveLength(2);
    expect(out.filter((line) => line === '::endgroup::')).toHaveLength(2);
  });

  it('puts a dropped BEGIN section inside its group, output and all', () => {
    // Truncation eats the head of the window, so the first surviving section
    // announces itself only at its END — after its output has been emitted.
    // Heading it there would leave a group holding nothing but the verdict
    // while hundreds of its lines sat loose above it.
    const out = render(
      plain(
        'alpha line one',
        'alpha line two',
        '===BATCH_TEST_END alpha PASS 10==='
      )
    );

    expect(out).toEqual([
      '::group::@quenty/alpha',
      'alpha line one',
      'alpha line two',
      '::endgroup::',
    ]);
  });

  it('leaves earlier top-level output above a dropped BEGIN section', () => {
    // Only the run since the last section closed belongs to the orphan; output
    // from before that is not retroactively swept into it.
    const out = render(
      plain(
        '===BATCH_TEST_BEGIN alpha===',
        'alpha ran',
        '===BATCH_TEST_END alpha PASS 10===',
        'loose line between packages',
        'beta output with no begin',
        '===BATCH_TEST_END beta PASS 20==='
      )
    );

    expect(out).toEqual([
      '::group::@quenty/alpha',
      'alpha ran',
      '::endgroup::',
      '::group::@quenty/beta',
      'loose line between packages',
      'beta output with no begin',
      '::endgroup::',
    ]);
  });

  it('carries the verdict in the group title, and the reason in its body', () => {
    // A group is read collapsed first, so the title has to say which ones are
    // worth opening. The reason is a sentence and stays in the body.
    const results = new Map([
      [
        '@quenty/alpha',
        result({
          success: false,
          error: 'no jest report in output',
          testCounts: { passed: 3, failed: 1, total: 4 },
          durationMs: 1500,
        }),
      ],
    ]);

    const out = render(
      plain(
        '===BATCH_TEST_BEGIN alpha===',
        'alpha ran',
        '===BATCH_TEST_END alpha FAIL 10==='
      ),
      results
    );

    expect(out).toEqual([
      '::group::@quenty/alpha - ❌ FAILED (3/4) (1.5s)',
      'alpha ran',
      'no jest report in output',
      '::endgroup::',
    ]);
  });

  it('titles a passing package with its counts and duration', () => {
    const results = new Map([
      [
        '@quenty/alpha',
        result({
          success: true,
          testCounts: { passed: 68, failed: 0, total: 68 },
          durationMs: 1500,
        }),
      ],
    ]);

    const out = render(
      plain(
        '===BATCH_TEST_BEGIN alpha===',
        '===BATCH_TEST_END alpha PASS 1==='
      ),
      results
    );

    expect(out[0]).toBe('::group::@quenty/alpha - ✅ Passed (68/68) (1.5s)');
  });

  it('titles a package with only its name when nothing is known about it', () => {
    const out = render(
      plain('===BATCH_TEST_BEGIN alpha===', '===BATCH_TEST_END alpha PASS 1===')
    );

    expect(out[0]).toBe('::group::@quenty/alpha');
  });

  it('drops the summary marker and its payload', () => {
    // Framing for the parser, not output a person reads.
    const out = render(
      plain(
        'real output',
        '===BATCH_TEST_SUMMARY===',
        '[{"slug":"alpha","success":true}]'
      )
    );

    expect(out).toEqual(['real output']);
  });

  it('leaves plain output untouched so jest keeps its own color', () => {
    const out = renderBatchLog(plain('[32m✓ passed[39m'), {
      slugToPackage: SLUGS,
      useGroups: true,
      color: true,
    });

    expect(out).toEqual(['[32m✓ passed[39m']);
  });

  it('colors warnings and errors by the severity the API reported', () => {
    const out = renderBatchLog(
      [
        { line: 'plain', severity: 'output' },
        { line: 'careful', severity: 'warning' },
        { line: 'broken', severity: 'error' },
      ],
      { slugToPackage: SLUGS, useGroups: true, color: true }
    );

    // Compared against the formatters themselves rather than asserting the text
    // changed: chalk emits no escapes on a non-TTY, so "it differs" would pass
    // or fail on where the suite runs rather than on what the renderer did.
    expect(out[0]).toBe('plain');
    expect(out[1]).toBe(OutputHelper.formatWarning('careful'));
    expect(out[2]).toBe(OutputHelper.formatError('broken'));
  });

  it('uses a plain header instead of group markers outside CI', () => {
    const out = renderBatchLog(
      plain(
        '===BATCH_TEST_BEGIN alpha===',
        'ran',
        '===BATCH_TEST_END alpha PASS 1==='
      ),
      { slugToPackage: SLUGS, useGroups: false, color: false }
    );

    expect(out.some((line) => line.includes('@quenty/alpha'))).toBe(true);
    expect(out).not.toContain('::group::@quenty/alpha');
    expect(out).not.toContain('::endgroup::');
  });
});

describe('toRenderableLines', () => {
  it('gives every line of a message the severity of that message', () => {
    // An error arrives with its traceback attached as one message. Classifying
    // by line would leave the continuation lines looking like ordinary output.
    const lines = toRenderableLines([
      { message: 'fine', messageType: 'OUTPUT' },
      {
        message:
          "TaskScript:1: boom\nStack Begin\nScript 'X', Line 1\nStack End",
        messageType: 'ERROR',
      },
    ]);

    expect(lines).toHaveLength(5);
    expect(lines[0]).toEqual({ line: 'fine', severity: 'output' });
    expect(lines.slice(1).every((l) => l.severity === 'error')).toBe(true);
    expect(lines[2].line).toBe('Stack Begin');
  });

  it('treats an untyped message as ordinary output', () => {
    // The flat log view carries no type, and a missing type must not read as
    // a failure.
    expect(toRenderableLines([{ message: 'hi' }])).toEqual([
      { line: 'hi', severity: 'output' },
    ]);
  });

  it('produces exactly the lines the parser tokenizes', () => {
    // The renderer maps token i onto line i, which only holds if this split is
    // the same one the fetch's joined text would produce.
    const messages = [
      { message: 'one', messageType: 'OUTPUT' },
      { message: 'two\nthree', messageType: 'WARNING' },
    ];
    const joined = messages.map((m) => m.message).join('\n');

    expect(toRenderableLines(messages).map((l) => l.line)).toEqual(
      joined.split('\n')
    );
  });
});
