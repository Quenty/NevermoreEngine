import { Argv, CommandModule } from 'yargs';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { InitGameCommand } from './init-game-command.js';
import { InitPackageCommand } from './init-package-command.js';
import { InitPluginCommand } from './init-plugin-command.js';

export class InitCommand<T> implements CommandModule<T, NevermoreGlobalArgs> {
  public command = 'init [type]';
  public describe = 'Scaffold a new game, package, or plugin';

  public builder = (args: Argv<T>) => {
    args.command(new InitGameCommand() as any);
    args.command(new InitPackageCommand() as any);
    args.command(new InitPluginCommand() as any);
    return args as Argv<NevermoreGlobalArgs>;
  };

  public handler = async () => {};
}
