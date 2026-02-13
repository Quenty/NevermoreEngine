import { Argv, CommandModule } from 'yargs';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { ciPostTestResultsCommand } from './ci-post-test-results.js';

export class CiCommand<T> implements CommandModule<T, NevermoreGlobalArgs> {
  public command = 'ci <subcommand>';
  public describe = 'CI-only commands (GitHub Actions integration)';

  public builder = (args: Argv<T>) => {
    args.command(ciPostTestResultsCommand as any);
    return args as Argv<NevermoreGlobalArgs>;
  };

  public handler = async () => {};
}
