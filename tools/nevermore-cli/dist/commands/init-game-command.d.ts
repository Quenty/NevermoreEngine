/**
 * Initialize a new game command
 */
import { Argv, CommandModule } from 'yargs';
import { NevermoreGlobalArgs } from '../args/global-args';
export interface InitGameArgs extends NevermoreGlobalArgs {
    gameName: string;
}
/**
 * Creates a new game with Nevermore dependencies
 */
export declare class InitGameCommand<T> implements CommandModule<T, InitGameArgs> {
    command: string;
    describe: string;
    builder(args: Argv<T>): Argv<InitGameArgs>;
    handler(args: InitGameArgs): Promise<void>;
    private static _createDirectoryContentsAsync;
    private static _runCommandAsync;
    private static _ensureGameName;
    private static _validateGameName;
}
//# sourceMappingURL=init-game-command.d.ts.map