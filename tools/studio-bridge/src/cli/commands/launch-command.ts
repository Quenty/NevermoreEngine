/**
 * `studio-bridge launch` -- launch Roblox Studio.
 */

import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { launchHandlerAsync } from '../../commands/launch.js';
import { formatAsJson, resolveMode } from '../format-output.js';

export interface LaunchArgs extends StudioBridgeGlobalArgs {
  json?: boolean;
}

export class LaunchCommand<T> implements CommandModule<T, LaunchArgs> {
  public command = 'launch';
  public describe = 'Launch Roblox Studio';

  public builder = (args: Argv<T>) => {
    args.option('json', {
      type: 'boolean',
      default: false,
      describe: 'Output as JSON',
    });

    return args as Argv<LaunchArgs>;
  };

  public handler = async (args: LaunchArgs) => {
    try {
      const result = await launchHandlerAsync({
        placePath: args.place,
      });

      const mode = resolveMode({ json: args.json });
      if (mode === 'json') {
        console.log(formatAsJson({
          launched: result.launched,
          summary: result.summary,
        }));
      } else {
        OutputHelper.info(result.summary);
      }
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  };
}
