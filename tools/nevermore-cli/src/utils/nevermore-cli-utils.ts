import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../args/global-args.js';
import { execa, Options } from 'execa';

/**
 * Gets a temlate path by name
 * @param name
 * @returns
 */
export function getTemplatePathByName(name: string) {
  return path.join(__dirname, '..', '..', 'templates', name);
}

export async function runCommandAsync(
  initGameArgs: NevermoreGlobalArgs,
  command: string,
  args: string[],
  options?: Options
): Promise<any> {
  if (initGameArgs.dryrun) {
    OutputHelper.info(
      `[DRYRUN]: Would have ran \`${command} ${args.join(' ')}\``
    );
  } else {
    OutputHelper.info(`Running \`${command} ${args.join(' ')}\``);

    const commandExec = execa(command, args, options);

    if (commandExec.stdout) {
      commandExec.stdout.pipe(process.stdout);
    }

    if (commandExec.stderr) {
      commandExec.stderr.pipe(process.stderr);
    }

    const result = await commandExec;

    OutputHelper.info(`Finished running '${result.command}'`);

    return result;
  }
}
