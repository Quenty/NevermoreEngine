import { Argv, CommandModule } from 'yargs';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { ciPostTestResultsCommand } from './ci-post-test-results.js';
import { DownloadRobloxTypes } from './download-roblox-types.js';
import { stripSourcemapJestCommand } from './strip-sourcemap-jest-command.js';

export class ToolsCommand<T> implements CommandModule<T, NevermoreGlobalArgs> {
  public command = 'tools <subcommand>';
  public describe = 'Internal tooling and CI utilities';

  public builder = (args: Argv<T>) => {
    args.command(ciPostTestResultsCommand as any);
    args.command(new DownloadRobloxTypes() as any);
    args.command(stripSourcemapJestCommand as any);
    return args as Argv<NevermoreGlobalArgs>;
  };

  public handler = async () => {};
}
