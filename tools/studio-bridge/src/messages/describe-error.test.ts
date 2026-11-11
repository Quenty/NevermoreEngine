import { describe, expect, it } from 'vitest';
import { describeError, UNEXPECTED_ERROR_CODE } from './describe-error.js';
import { StudioBridgeError } from './studio-bridge-error.js';

const outdated = new StudioBridgeError({
  code: 'PLUGIN_OUTDATED',
  message: "The studio-bridge plugin in 'Baseplate' is out of date.",
  fix: 'Run the command again with --update-plugin.',
  cause: 'Installed plugin build ff77f7, this CLI needs 1aa54d',
});

describe('describeError', () => {
  it('reports an expected failure as its message and fix, without its cause', () => {
    expect(describeError(outdated, false)).toEqual({
      code: 'PLUGIN_OUTDATED',
      error: "The studio-bridge plugin in 'Baseplate' is out of date.",
      fix: 'Run the command again with --update-plugin.',
    });
  });

  it('adds the cause under --verbose', () => {
    expect(describeError(outdated, true).cause).toBe(
      'Installed plugin build ff77f7, this CLI needs 1aa54d'
    );
  });

  it('reports anything else as unexpected, by its first line only', () => {
    const bug = new Error(
      'Cannot read properties of undefined\n    at foo.js:1'
    );

    expect(describeError(bug, false)).toEqual({
      code: UNEXPECTED_ERROR_CODE,
      error:
        'Unexpected error: Cannot read properties of undefined. Run with --verbose for details.',
    });
  });

  it('does not double the full stop of an unexpected error', () => {
    expect(describeError(new Error('Boom.'), false).error).toBe(
      'Unexpected error: Boom. Run with --verbose for details.'
    );
  });

  it('shows the stack of an unexpected error under --verbose', () => {
    const bug = new Error('Boom');

    const report = describeError(bug, true);

    expect(report.error).toBe('Unexpected error: Boom.');
    expect(report.cause).toContain('at ');
  });

  it('follows the cause chain under --verbose', () => {
    const err = new StudioBridgeError({
      code: 'X',
      message: 'Outer.',
      cause: new Error('middle', { cause: new Error('root') }),
    });

    const cause = describeError(err, true).cause ?? '';

    expect(cause).toContain('middle');
    expect(cause).toContain('Caused by: Error: root');
  });

  it('reports a thrown non-error as unexpected', () => {
    expect(describeError('nope', false).error).toBe(
      'Unexpected error: nope. Run with --verbose for details.'
    );
  });
});
