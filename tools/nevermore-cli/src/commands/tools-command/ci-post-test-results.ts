import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import {
  type IStateTracker,
  type Reporter,
  GithubCommentTableReporter,
  GithubJobSummaryReporter,
  LoadedStateTracker,
  createTestCommentConfig,
} from '../../utils/testing/reporting/index.js';

type ErrorReporter = Reporter & {
  setError(error: string): void;
  setNoTestsRun(message: string): void;
};

interface CiPostTestResultsArgs extends NevermoreGlobalArgs {
  input: string;
  runOutcome?: string;
}

/** Create the standard set of GitHub reporters for posting results. */
function _createGithubReporters(
  state: IStateTracker | undefined,
  concurrency?: number
): ErrorReporter[] {
  const config = createTestCommentConfig();
  return [
    new GithubCommentTableReporter(state, config, concurrency),
    new GithubJobSummaryReporter(state, config, concurrency),
  ];
}

export const ciPostTestResultsCommand: CommandModule<
  NevermoreGlobalArgs,
  CiPostTestResultsArgs
> = {
  command: 'post-test-results <input>',
  describe:
    'Post test results as a PR comment (requires GITHUB_TOKEN and CI context)',
  builder: (yargs) => {
    return yargs
      .positional('input', {
        describe: 'Path to test-results.json',
        type: 'string',
        demandOption: true,
      })
      .option('run-outcome', {
        describe:
          'Outcome of the test step (e.g. "success", "failure"). ' +
          'When the results file is missing and run-outcome is "success", ' +
          'posts a neutral "no tests" comment instead of an error.',
        type: 'string',
      });
  },
  handler: async (args) => {
    try {
      let state: LoadedStateTracker;
      try {
        state = await LoadedStateTracker.fromFileAsync(args.input);
      } catch {
        OutputHelper.warn(`Results file not found: ${args.input}`);

        const reporters = _createGithubReporters(undefined);

        if (args.runOutcome === 'success') {
          OutputHelper.info('Test step succeeded — posting informational comment to PR...');
          for (const r of reporters) {
            r.setNoTestsRun(
              'No changed packages with test targets were discovered for this PR.'
            );
          }
        } else {
          OutputHelper.info('Test step failed — posting failure comment to PR...');
          for (const r of reporters) {
            r.setError(
              `Results file not found: ${args.input}\nThe test run likely crashed before completing.`
            );
          }
        }

        for (const r of reporters) {
          await r.stopAsync();
        }
        return;
      }

      const reporters = _createGithubReporters(state, 1);
      for (const r of reporters) {
        await r.stopAsync();
      }
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  },
};
