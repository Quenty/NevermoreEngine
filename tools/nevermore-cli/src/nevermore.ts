#!/usr/bin/env node

/**
 * Main entry point for Nevermore command helper
 */

import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { VersionChecker } from '@quenty/nevermore-cli-helpers';

import { InitCommand } from './commands/init-command/index.js';
import { InitPackageCommand } from './commands/init-command/init-package-command.js';
import { InitPluginCommand } from './commands/init-command/init-plugin-command.js';
import { InstallPackageCommand } from './commands/install-package-command.js';
import { TestProjectCommand } from './commands/test-command.js';
import { DeployCommand } from './commands/deploy-command/index.js';
import { LoginCommand } from './commands/login-command.js';
import { BatchCommand } from './commands/batch-command/index.js';
import { ToolsCommand } from './commands/tools-command/index.js';
import { DownloadRobloxTypes } from './commands/tools-command/download-roblox-types.js';

const versionData = await VersionChecker.checkForUpdatesAsync({
  humanReadableName: 'Nevermore CLI',
  packageName: '@quenty/nevermore-cli',
  registryUrl: 'https://registry.npmjs.org/',
  packageJsonPath: join(
    dirname(fileURLToPath(import.meta.url)),
    '../package.json'
  ),
});

yargs(hideBin(process.argv))
  .scriptName('nevermore')
  .version(
    (versionData
      ? VersionChecker.getVersionDisplayName(versionData)
      : undefined) as any
  )
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
  .command(new InitCommand() as any)
  .command(new InstallPackageCommand() as any)
  .command(new TestProjectCommand() as any)
  .command(new DeployCommand() as any)
  .command(new BatchCommand() as any)
  .command(new ToolsCommand() as any)
  .command(new LoginCommand() as any)
  // Back-compat aliases: hidden from --help but still functional
  .command({ ...new DownloadRobloxTypes(), describe: false } as any)
  .command({
    ...new InitPackageCommand(),
    command: 'init-package [package-name] [description] [package-template]',
    describe: false,
  } as any)
  .command({
    ...new InitPluginCommand(),
    command: 'init-plugin [plugin-name]',
    describe: false,
  } as any)
  .recommendCommands()
  .demandCommand(
    1,
    OutputHelper.formatHint("Hint: See 'nevermore help' for more help")
  )
  .wrap(null)
  .strict().argv;
