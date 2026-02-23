/**
 * `studio-bridge install-plugin` -- install the persistent Studio Bridge plugin.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { installPluginHandlerAsync } from '../../commands/install-plugin.js';

export class InstallPluginCommand<T> implements CommandModule<T, StudioBridgeGlobalArgs> {
  public command = 'install-plugin';
  public describe = 'Install the persistent Studio Bridge plugin';

  public builder = (args: Argv<T>) => {
    return args as Argv<StudioBridgeGlobalArgs>;
  };

  public handler = async (_args: StudioBridgeGlobalArgs) => {
    try {
      const result = await installPluginHandlerAsync();
      OutputHelper.info(result.summary);
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  };
}
