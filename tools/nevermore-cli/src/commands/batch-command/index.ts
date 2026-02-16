import { Argv, CommandModule } from 'yargs';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { batchDeployCommand } from './batch-deploy-command.js';
import { batchTestCommand } from './batch-test-command.js';

export class BatchCommand<T> implements CommandModule<T, NevermoreGlobalArgs> {
  public command = 'batch <subcommand>';
  public describe = 'Run operations across multiple packages';

  public builder = (args: Argv<T>) => {
    args.command(batchDeployCommand as any);
    args.command(batchTestCommand as any);
    return args as Argv<NevermoreGlobalArgs>;
  };

  public handler = async () => {};
}
