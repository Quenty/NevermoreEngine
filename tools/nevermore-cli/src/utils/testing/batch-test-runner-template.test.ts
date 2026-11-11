/**
 * Guards the two names the batch runner template spells out by hand.
 *
 * The template is raw Luau with no loader, so it cannot import anything: it
 * recognizes a results table by a format string and finds the runner's state by
 * a module name, both written as literals. Nothing else connects those literals
 * to the Luau they describe — rename either side and the batch silently loses
 * every package's counts, which looks exactly like a truncated log.
 */

import { describe, it, expect } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';
import { resolvePackagePath } from '@quenty/nevermore-template-helpers';

const TEMPLATE = fs.readFileSync(
  resolvePackagePath(import.meta.url, 'templates', 'batch-test-runner.lua'),
  'utf-8'
);

/** The nevermore-test-runner package this template is written against. */
const RUNNER_DIR = path.resolve(
  resolvePackagePath(import.meta.url, '..', '..'),
  'src',
  'nevermore-test-runner',
  'src',
  'Server'
);

function literal(name: string): string {
  const match = new RegExp(`local ${name} = "([^"]+)"`).exec(TEMPLATE);
  expect(match, `${name} is not declared in the template`).toBeTruthy();
  return match![1];
}

describe('batch-test-runner.lua', () => {
  it('names a state module that exists in the test runner package', () => {
    const moduleName = literal('STATE_MODULE_NAME');

    expect(
      fs.existsSync(
        path.join(RUNNER_DIR, 'NevermoreTestRunnerUtils', `${moduleName}.lua`)
      )
    ).toBe(true);
  });

  it('agrees with the test runner about the results format tag', () => {
    const results = fs.readFileSync(
      path.join(RUNNER_DIR, 'NevermoreTestResults.lua'),
      'utf-8'
    );

    expect(results).toContain(`local FORMAT = "${literal('RESULTS_FORMAT')}"`);
  });

  it('returns its summary as well as printing it', () => {
    // The return value is the copy the engine's log buffer cannot truncate.
    // Losing it would leave the printed summary as the only channel, which is
    // the failure the whole path exists to survive.
    expect(TEMPLATE.trimEnd().endsWith('return results')).toBe(true);
  });
});
