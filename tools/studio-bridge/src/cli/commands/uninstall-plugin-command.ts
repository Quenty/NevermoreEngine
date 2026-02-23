/**
 * `studio-bridge uninstall-plugin` -- remove the persistent Studio Bridge plugin.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { uninstallPluginHandlerAsync } from '../../commands/uninstall-plugin.js';

export class UninstallPluginCommand<T> implements CommandModule<T, StudioBridgeGlobalArgs> {
  public command = 'uninstall-plugin';
  public describe = 'Remove the persistent Studio Bridge plugin';

  public builder = (args: Argv<T>) => {
    return args as Argv<StudioBridgeGlobalArgs>;
  };

  public handler = async (_args: StudioBridgeGlobalArgs) => {
    try {
      const result = await uninstallPluginHandlerAsync();
      OutputHelper.info(result.summary);
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  };
}
