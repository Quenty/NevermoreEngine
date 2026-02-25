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
 *   studio-bridge terminal [--script <file.lua>]
 */

import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { VersionChecker } from '@quenty/nevermore-cli-helpers';

import { CommandRegistry } from '../commands/framework/command-registry.js';
import { buildGroupCommands } from './adapters/group-builder.js';
import { resolvePlacePathAsync } from './script-executor.js';

// Command definitions (explicit imports for deterministic ordering)
import { execCommand } from '../commands/console/exec/exec.js';
import { logsCommand } from '../commands/console/logs/logs.js';
import { queryCommand } from '../commands/explorer/query/query.js';
import { screenshotCommand } from '../commands/viewport/screenshot/screenshot.js';
import { infoCommand } from '../commands/process/info/info.js';
import { listCommand } from '../commands/process/list/list.js';
import { launchCommand } from '../commands/process/launch/launch.js';
import { processRunCommand } from '../commands/process/run/run.js';
import { processCloseCommand } from '../commands/process/close/close.js';
import { installCommand } from '../commands/plugin/install/install.js';
import { uninstallCommand } from '../commands/plugin/uninstall/uninstall.js';
import { serveCommand } from '../commands/serve/serve.js';
import { mcpCommand } from '../commands/mcp/mcp.js';
import { terminalCommand } from '../commands/terminal/terminal.js';
import { actionCommand } from '../commands/action/action.js';

// ---------------------------------------------------------------------------
// Build registry
// ---------------------------------------------------------------------------

const registry = new CommandRegistry();

// Execution commands
registry.register(execCommand);
registry.register(logsCommand);
registry.register(queryCommand);
registry.register(screenshotCommand);
registry.register(processRunCommand);
registry.register(actionCommand);

// Infrastructure commands
registry.register(infoCommand);
registry.register(listCommand);
registry.register(launchCommand);
registry.register(processCloseCommand);
registry.register(installCommand);
registry.register(uninstallCommand);
registry.register(serveCommand);
registry.register(mcpCommand);
registry.register(terminalCommand);

// ---------------------------------------------------------------------------
// Build yargs commands from registry
// ---------------------------------------------------------------------------

const { groups, topLevel } = buildGroupCommands(registry);

// ---------------------------------------------------------------------------
// Version check
// ---------------------------------------------------------------------------

const versionData = await VersionChecker.checkForUpdatesAsync({
  humanReadableName: 'Studio Bridge',
  packageName: '@quenty/studio-bridge',
  registryUrl: 'https://registry.npmjs.org/',
  packageJsonPath: join(
    dirname(fileURLToPath(import.meta.url)),
    '../../../package.json'
  ),
});

// ---------------------------------------------------------------------------
// CLI setup
// ---------------------------------------------------------------------------

const cli = yargs(hideBin(process.argv))
  .scriptName('studio-bridge')
  .version(
    (versionData
      ? VersionChecker.getVersionDisplayName(versionData)
      : undefined) as any
  )
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
  .usage(OutputHelper.formatInfo('Usage: $0 <command> [options]'));

// Register grouped commands (console, explorer, viewport, process, plugin)
for (const group of groups) {
  cli.command(group as any);
}

// Register top-level commands from registry (serve, mcp, action)
// Terminal is handled separately below due to its custom REPL handler
for (const cmd of topLevel) {
  const cmdDef = cmd as { command?: string };
  // Skip terminal — handled with custom handler below
  if (typeof cmdDef.command === 'string' && cmdDef.command.startsWith('terminal')) {
    continue;
  }
  cli.command(cmd as any);
}

// Terminal command with custom REPL handler (escape hatch)
cli.command({
  command: 'terminal',
  describe: terminalCommand.description,
  builder: (args: any) => {
    args.option('script', {
      alias: 's',
      describe: 'Path to a Luau script to run on connect',
      type: 'string',
    });
    args.option('script-text', {
      alias: 't',
      describe: 'Inline Luau code to run on connect',
      type: 'string',
    });
    args.option('place', {
      alias: 'p',
      description:
        'Path to a .rbxl place file (builds a minimal place via rojo if omitted)',
      type: 'string',
    });
    return args;
  },
  handler: async (argv: any) => {
    try {
      const placePath = await resolvePlacePathAsync(argv.place);

      const { runTerminalMode } = await import(
        './commands/terminal/terminal-mode.js'
      );
      await runTerminalMode({
        placePath,
        scriptPath: argv.script,
        scriptText: argv['script-text'],
        timeoutMs: argv.timeout,
        verbose: argv.verbose,
      });
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  },
} as any);

cli
  .recommendCommands()
  .demandCommand(
    1,
    OutputHelper.formatHint("Hint: See 'studio-bridge help' for more help")
  )
  .wrap(null)
  .strict().argv;
