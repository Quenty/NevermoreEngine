import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { GithubCommentTestReporter } from '../../utils/testing/reporting/github-comment-test-reporter.js';
import { LoadedTestStateTracker } from '../../utils/testing/reporting/state/loaded-test-state-tracker.js';

interface CiPostTestResultsArgs extends NevermoreGlobalArgs {
  input: string;
}

export const ciPostTestResultsCommand: CommandModule<
  NevermoreGlobalArgs,
  CiPostTestResultsArgs
> = {
  command: 'post-test-results <input>',
  describe:
    'Post test results as a PR comment (requires GITHUB_TOKEN and CI context)',
  builder: (yargs) => {
    return yargs.positional('input', {
      describe: 'Path to test-results.json',
      type: 'string',
      demandOption: true,
    });
  },
  handler: async (args) => {
    const reporter = new GithubCommentTestReporter();

    try {
      let state: LoadedTestStateTracker;
      try {
        state = await LoadedTestStateTracker.fromFileAsync(args.input);
      } catch {
        OutputHelper.warn(`Results file not found: ${args.input}`);
        OutputHelper.info('Posting failure comment to PR...');
        reporter.setError(
          `Results file not found: ${args.input}\nThe test run likely crashed before completing.`
        );
        await reporter.stopAsync();
        return;
      }

      const resultsReporter = new GithubCommentTestReporter(state, 1);
      await resultsReporter.stopAsync();
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  },
};
