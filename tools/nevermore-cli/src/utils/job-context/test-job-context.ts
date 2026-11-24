import {
  type ScriptJobContext,
  type ScriptRunResult,
} from '@quenty/nevermore-job-helpers';
import { type StructuredTestResults } from '../testing/structured-test-results.js';

export interface TestScriptRunResult extends ScriptRunResult {
  /**
   * The run's structured test results, when the context resolved them itself
   * rather than leaving them in `returnValues` for the caller to decode.
   *
   * Only aggregated batch mode sets this: one execution covers every package, so
   * its return value belongs to no single one of them and the per-package
   * results have to be recovered from the batch summary first. A context that
   * sets this has also reported where the counts came from, so the caller does
   * not report it a second time.
   */
  testResults?: StructuredTestResults;
}

export type TestJobContext = ScriptJobContext<TestScriptRunResult>;
