import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import {
  GithubCommentTableReporter,
  LoadedStateTracker,
  createTestCommentConfig,
} from '../../utils/testing/reporting/index.js';

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
    const testCommentConfig = createTestCommentConfig();
    const reporter = new GithubCommentTableReporter(undefined, testCommentConfig);

    try {
      let state: LoadedStateTracker;
      try {
        state = await LoadedStateTracker.fromFileAsync(args.input);
      } catch {
        OutputHelper.warn(`Results file not found: ${args.input}`);
        OutputHelper.info('Posting failure comment to PR...');
        reporter.setError(
          `Results file not found: ${args.input}\nThe test run likely crashed before completing.`
        );
        await reporter.stopAsync();
        return;
      }

      const resultsReporter = new GithubCommentTableReporter(state, testCommentConfig, 1);
      await resultsReporter.stopAsync();
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  },
};
