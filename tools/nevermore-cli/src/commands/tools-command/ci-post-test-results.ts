import * as fs from 'fs/promises';
import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { BatchTestSummary } from '../../utils/testing/batch-test-runner.js';
import {
  postTestResultsCommentAsync,
  postTestRunFailedCommentAsync,
} from '../../utils/testing/github-comment.js';

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
    try {
      let raw: string;
      try {
        raw = await fs.readFile(args.input, 'utf-8');
      } catch {
        // Results file missing — test run crashed before writing output
        OutputHelper.warn(`Results file not found: ${args.input}`);
        OutputHelper.info('Posting failure comment to PR...');
        await postTestRunFailedCommentAsync(
          `Results file not found: ${args.input}\nThe test run likely crashed before completing.`
        );
        return;
      }

      const results = JSON.parse(raw) as BatchTestSummary;
      const posted = await postTestResultsCommentAsync(results);

      if (!posted) {
        OutputHelper.warn('PR comment was not posted (see warnings above).');
      }
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  },
};
