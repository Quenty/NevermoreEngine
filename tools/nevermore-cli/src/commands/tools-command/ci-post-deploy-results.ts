import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  type IStateTracker,
  type Reporter,
  GithubCommentTableReporter,
  GithubJobSummaryReporter,
  LoadedStateTracker,
} from '@quenty/cli-output-helpers/reporting';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { createDeployCommentConfig } from '../../utils/deploy/deploy-github-columns.js';

type ErrorReporter = Reporter & {
  setError(error: string): void;
  setNoTestsRun(message: string): void;
};

interface CiPostDeployResultsArgs extends NevermoreGlobalArgs {
  input: string;
  runOutcome?: string;
}

/** Create the standard set of GitHub reporters for posting deploy results. */
function _createGithubReporters(
  state: IStateTracker | undefined,
  concurrency?: number
): ErrorReporter[] {
  const config = createDeployCommentConfig();
  return [
    new GithubCommentTableReporter(state, config, concurrency),
    new GithubJobSummaryReporter(state, config, concurrency),
  ];
}

export const ciPostDeployResultsCommand: CommandModule<
  NevermoreGlobalArgs,
  CiPostDeployResultsArgs
> = {
  command: 'post-deploy-results <input>',
  describe:
    'Post deploy results as a PR comment (requires GITHUB_TOKEN and CI context)',
  builder: (yargs) => {
    return yargs
      .positional('input', {
        describe: 'Path to deploy-results.json',
        type: 'string',
        demandOption: true,
      })
      .option('run-outcome', {
        describe:
          'Outcome of the deploy step (e.g. "success", "failure"). ' +
          'When the results file is missing and run-outcome is "success", ' +
          'posts a neutral "no deploys" comment instead of an error.',
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
          OutputHelper.info('Deploy step succeeded — posting informational comment to PR...');
          for (const r of reporters) {
            r.setNoTestsRun(
              'No changed packages with deploy targets were discovered for this PR.'
            );
          }
        } else {
          OutputHelper.info('Deploy step failed — posting failure comment to PR...');
          for (const r of reporters) {
            r.setError(
              `Results file not found: ${args.input}\nThe deploy run likely crashed before completing.`
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
