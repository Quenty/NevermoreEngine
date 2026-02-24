/**
 * `studio-bridge screenshot` -- capture a screenshot from Studio.
 */

import { writeFile } from 'fs/promises';
import { Argv, CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { StudioBridgeGlobalArgs } from '../args/global-args.js';
import { captureScreenshotHandlerAsync } from '../../commands/screenshot.js';
import { formatAsJson, resolveMode } from '../format-output.js';
import { addSessionOptions, withSessionAsync } from '../with-connection.js';
import type { SessionCommandOptions } from '../with-connection.js';

export interface ScreenshotArgs extends StudioBridgeGlobalArgs, SessionCommandOptions {
  output?: string;
  base64?: boolean;
  open?: boolean;
}

export class ScreenshotCommand<T> implements CommandModule<T, ScreenshotArgs> {
  public command = 'screenshot';
  public describe = 'Capture a screenshot from Studio';

  public builder = (args: Argv<T>) => {
    addSessionOptions(args);
    args.option('output', {
      alias: 'o',
      type: 'string',
      describe: 'File path to write the PNG screenshot',
    });
    args.option('base64', {
      type: 'boolean',
      default: false,
      describe: 'Output raw base64 data',
    });
    args.option('open', {
      type: 'boolean',
      default: false,
      describe: 'Open the screenshot after saving',
    });

    return args as Argv<ScreenshotArgs>;
  };

  public handler = async (args: ScreenshotArgs) => {
    await withSessionAsync(args, async (session) => {
      const result = await captureScreenshotHandlerAsync(session, {
        output: args.output,
        base64: args.base64,
      });

      const mode = resolveMode({ json: args.json });

      if (mode === 'json') {
        console.log(
          formatAsJson({
            width: result.width,
            height: result.height,
            data: result.data,
          })
        );
        return;
      }

      // Write to file if --output is specified
      if (args.output) {
        const buffer = Buffer.from(result.data, 'base64');
        await writeFile(args.output, buffer);
        OutputHelper.info(`Screenshot saved to ${args.output}`);
        return;
      }

      // Output raw base64 if --base64 is specified
      if (args.base64) {
        console.log(result.data);
        return;
      }

      // Default: print summary
      OutputHelper.info(result.summary);
    });
  };
}
