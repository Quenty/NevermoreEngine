#!/usr/bin/env node

/**
 * Main entry point for Nevermore command helper
 */

import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import { OutputHelper } from '@quenty/cli-output-helpers';

import { InitGameCommand } from './commands/init-game-command';
import { InitPackageCommand } from './commands/init-package-command';

yargs(hideBin(process.argv))
  .scriptName('nevermore')
  .version()
  .option('yes', {
    description: 'True if this run should not prompt the user in any way',
    default: false,
    global: true,
    type: 'boolean',
  })
  .option('dryrun', {
    description:
      "True if this run is a dryrun and shouldn't affect the file system",
    default: false,
    global: true,
    type: 'boolean',
  })
  .usage(OutputHelper.formatInfo('Usage: $0 <command> [options]'))
  .command(new InitGameCommand())
  .command(new InitPackageCommand())
  .recommendCommands()
  .demandCommand(
    1,
    OutputHelper.formatHint("Hint: See 'raven help' for more help")
  )
  .wrap(null)
  .strict().argv;
