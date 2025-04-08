#!/usr/bin/env node

/**
 * Main entry point for Nevermore command helper
 */

import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import { OutputHelper } from '@quenty/cli-output-helpers';

import { InitGameCommand } from './commands/init-game-command';
import { InitPackageCommand } from './commands/init-package-command';
import { InitPluginCommand } from './commands/init-plugin-command';
import { PackCommand } from './commands/pack-command';
import { InstallPackageCommand } from './commands/install-package-command';
import { TestProjectCommand } from './commands/test-project-command';

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
  .command(new InitGameCommand() as any)
  .command(new InitPackageCommand() as any)
  .command(new InitPluginCommand() as any)
  .command(new PackCommand() as any)
  .command(new InstallPackageCommand() as any)
  .command(new TestProjectCommand() as any)
  .recommendCommands()
  .demandCommand(
    1,
    OutputHelper.formatHint("Hint: See 'nevermore help' for more help")
  )
  .wrap(null)
  .strict().argv;