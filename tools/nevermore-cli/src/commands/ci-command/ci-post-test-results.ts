import * as fs from 'fs/promises';
import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { BatchTestSummary } from '../../utils/testing/batch-test-runner.js';
import { postTestResultsCommentAsync } from '../../utils/testing/github-comment.js';

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
      const raw = await fs.readFile(args.input, 'utf-8');
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
