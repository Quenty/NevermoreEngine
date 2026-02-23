#!/usr/bin/env node

/**
 * CLI entry point for @quenty/studio-bridge.
 *
 * Usage:
 *   studio-bridge run <file.lua>
 *   studio-bridge exec 'print("hello")'
 *   studio-bridge terminal [--script <file.lua>]
 *   studio-bridge sessions
 */

import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { VersionChecker } from '@quenty/nevermore-cli-helpers';

import { RunCommand } from './commands/run-command.js';
import { ExecCommand } from './commands/exec-command.js';
import { TerminalCommand } from './commands/terminal/terminal-command.js';
import { SessionsCommand } from './commands/sessions-command.js';
import { ServeCommand } from './commands/serve-command.js';
import { InstallPluginCommand } from './commands/install-plugin-command.js';
import { UninstallPluginCommand } from './commands/uninstall-plugin-command.js';

const versionData = await VersionChecker.checkForUpdatesAsync({
  humanReadableName: 'Studio Bridge',
  packageName: '@quenty/studio-bridge',
  registryUrl: 'https://registry.npmjs.org/',
  packageJsonPath: join(
    dirname(fileURLToPath(import.meta.url)),
    '../../../package.json'
  ),
});

yargs(hideBin(process.argv))
  .scriptName('studio-bridge')
  .version(
    (versionData
      ? VersionChecker.getVersionDisplayName(versionData)
      : undefined) as any
  )
  .option('place', {
    alias: 'p',
    description:
      'Path to a .rbxl place file (builds a minimal place via rojo if omitted)',
    type: 'string',
    global: true,
  })
  .option('timeout', {
    description: 'Timeout in milliseconds',
    type: 'number',
    default: 120_000,
    global: true,
  })
  .option('verbose', {
    description: 'Show internal debug output',
    type: 'boolean',
    default: false,
    global: true,
  })
  .option('logs', {
    description: 'Show execution logs in spinner mode',
    type: 'boolean',
    default: true,
    global: true,
  })
  .option('remote', {
    type: 'string',
    description: 'Connect to a remote bridge host (host:port)',
    global: true,
  })
  .option('local', {
    type: 'boolean',
    description: 'Force local mode (skip devcontainer auto-detection)',
    default: false,
    global: true,
    conflicts: 'remote',
  })
  .middleware((argv) => {
    OutputHelper.setVerbose(argv.verbose as boolean);
  })
  .usage(OutputHelper.formatInfo('Usage: $0 <command> [options]'))
  .command(new ExecCommand() as any)
  .command(new RunCommand() as any)
  .command(new TerminalCommand() as any)
  .command(new SessionsCommand() as any)
  .command(new ServeCommand() as any)
  .command(new InstallPluginCommand() as any)
  .command(new UninstallPluginCommand() as any)
  .recommendCommands()
  .demandCommand(
    1,
    OutputHelper.formatHint("Hint: See 'studio-bridge help' for more help")
  )
  .wrap(null)
  .strict().argv;
