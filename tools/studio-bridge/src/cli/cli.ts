#!/usr/bin/env node

/**
 * CLI entry point for @quenty/studio-bridge.
 *
 * Registry-driven: all commands are `defineCommand()` definitions discovered
 * from `src/commands/`. The adapter layer converts them into yargs modules.
 *
 * Usage:
 *   studio-bridge console exec 'print("hello")'
 *   studio-bridge console logs
 *   studio-bridge process list
 */

import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { VersionChecker } from '@quenty/nevermore-cli-helpers';
import { addWarning, setJsonOutput } from './cli-output-context.js';

import { CommandRegistry } from '../commands/framework/command-registry.js';
import { buildGroupCommands } from './adapters/group-builder.js';

// Command definitions (explicit imports for deterministic ordering)
import { execCommand } from '../commands/console/exec/exec.js';
import { logsCommand } from '../commands/console/logs/logs.js';
import { queryCommand } from '../commands/explorer/query/query.js';
import { exportCommand } from '../commands/explorer/export/export.js';
import { importCommand } from '../commands/explorer/import/import.js';
import { findCommand } from '../commands/explorer/find/find.js';
import { grepCommand } from '../commands/explorer/grep/grep.js';
import { screenshotCommand } from '../commands/viewport/screenshot/screenshot.js';
import { infoCommand } from '../commands/process/info/info.js';
import { listCommand } from '../commands/process/list/list.js';
import { launchCommand } from '../commands/process/launch/launch.js';
import { processRunCommand } from '../commands/process/run/run.js';
import { processCloseCommand } from '../commands/process/close/close.js';
import { playtestStartCommand } from '../commands/playtest/start/start.js';
import { playtestStopCommand } from '../commands/playtest/stop/stop.js';
import { playtestRunCommand } from '../commands/playtest/run/run.js';
import { playtestRestartCommand } from '../commands/playtest/restart/restart.js';
import { playtestPlayerListCommand } from '../commands/playtest/player/list/list.js';
import { playtestPlayerAddCommand } from '../commands/playtest/player/add/add.js';
import { playtestPlayerRemoveCommand } from '../commands/playtest/player/remove/remove.js';
import { installCommand } from '../commands/plugin/install/install.js';
import { uninstallCommand } from '../commands/plugin/uninstall/uninstall.js';
import { serveCommand } from '../commands/serve/serve.js';
import { linuxSetupCommand } from '../commands/linux/setup/setup.js';
import { linuxInjectCredentialsCommand } from '../commands/linux/inject-credentials/inject-credentials.js';
import { linuxStatusCommand } from '../commands/linux/status/status.js';

const registry = new CommandRegistry();

// Execution commands
registry.register(execCommand);
registry.register(logsCommand);
registry.register(queryCommand);
registry.register(exportCommand);
registry.register(importCommand);
registry.register(findCommand);
registry.register(grepCommand);
registry.register(screenshotCommand);
registry.register(launchCommand);
registry.register(playtestStartCommand);
registry.register(playtestStopCommand);
registry.register(playtestRunCommand);
registry.register(playtestRestartCommand);
registry.register(playtestPlayerListCommand);
registry.register(playtestPlayerAddCommand);
registry.register(playtestPlayerRemoveCommand);

// Infrastructure commands
registry.register(listCommand);
registry.register(infoCommand);
registry.register(processCloseCommand);
registry.register(processRunCommand);
registry.register(installCommand);
registry.register(uninstallCommand);
registry.register(serveCommand);

// Linux commands
registry.register(linuxSetupCommand);
registry.register(linuxInjectCredentialsCommand);
registry.register(linuxStatusCommand);

const { groups, topLevel } = buildGroupCommands(registry);

OutputHelper.setDiagnosticsToStderr(true);

const formatIndex = process.argv.indexOf('--format');
const isMachineReadable =
  process.argv.includes('--format=json') ||
  (formatIndex !== -1 && process.argv[formatIndex + 1] === 'json');
setJsonOutput(isMachineReadable);

const versionData = await VersionChecker.checkForUpdatesAsync({
  humanReadableName: 'Studio Bridge',
  packageName: '@quenty/studio-bridge',
  registryUrl: 'https://registry.npmjs.org/',
  packageJsonPath: join(
    dirname(fileURLToPath(import.meta.url)),
    '../../../package.json'
  ),
  silent: isMachineReadable,
});

if (isMachineReadable && versionData) {
  if (versionData.isLocalDev) {
    addWarning(
      `Studio Bridge is running in local development mode. Run 'npm install -g @quenty/studio-bridge@latest' to switch to production copy.`
    );
  } else if (versionData.updateAvailable) {
    addWarning(
      `Studio Bridge update available: ${VersionChecker.getVersionDisplayName(
        versionData
      )} → ${
        versionData.latestVersion
      }. Run 'npm install -g @quenty/studio-bridge@latest' to update.`
    );
  }
}

const cli = yargs(hideBin(process.argv))
  .scriptName('studio-bridge')
  .version(
    (versionData
      ? VersionChecker.getVersionDisplayName(versionData)
      : undefined) as any
  )
  .option('timeout', {
    description:
      'How long to wait for a Studio session to connect, in milliseconds',
    type: 'number',
    global: true,
  })
  .option('verbose', {
    description: 'Show internal debug output',
    type: 'boolean',
    default: false,
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
  .example(
    '$0 process launch',
    "Open the place of the nearest deploy.nevermore.json's default target in Studio"
  )
  .example('$0 process list', 'List the connected Studio sessions')
  .example(
    "$0 console exec 'return workspace:GetChildren()'",
    'Run Luau in Studio and print what it returns'
  )
  .example('$0 playtest start', 'Start a playtest');

// Register grouped commands (console, explorer, viewport, process, plugin)
for (const group of groups) {
  cli.command(group as any);
}

// Register top-level commands from registry (serve)
for (const cmd of topLevel) {
  cli.command(cmd as any);
}

cli
  .recommendCommands()
  .demandCommand(
    1,
    OutputHelper.formatHint("Hint: See 'studio-bridge help' for more help")
  )
  .wrap(null)
  .parserConfiguration({ 'populate--': true })
  .strict().argv;
