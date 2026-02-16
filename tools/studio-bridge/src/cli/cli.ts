#!/usr/bin/env node

/**
 * CLI entry point for @quenty/studio-bridge.
 *
 * Usage:
 *   studio-bridge --script <path.lua>
 *   studio-bridge --script-text 'print("hello")'
 *   studio-bridge --place <path.rbxl> --script <path.lua>
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { parseArgs } from 'node:util';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  CompositeReporter,
  SimpleReporter,
  SpinnerReporter,
  type LiveStateTracker,
} from '@quenty/cli-output-helpers/reporting';
import {
  StudioBridgeServer,
  type StudioBridgePhase,
} from '../server/studio-bridge-server.js';

const HELP = `
studio-bridge — run Luau scripts in Roblox Studio via WebSocket bridge

Usage:
  studio-bridge --script <file.lua>
  studio-bridge --script-text 'print("hello")'
  studio-bridge --place <file.rbxl> --script <file.lua>

Options:
  --place, -p        Path to a .rbxl place file (optional — builds a
                     minimal place via rojo if omitted)
  --script, -s       Path to a Luau script file to execute
  --script-text, -t  Inline Luau script text to execute
  --timeout          Timeout in milliseconds (default: 120000)
  --verbose          Show internal debug output
  --help, -h         Show this help message
  --version, -v      Show version
  --logs             Show execution logs in spinner mode (default: true)

Either --script or --script-text is required.
`.trim();

async function main() {
  const { values } = parseArgs({
    options: {
      place: { type: 'string', short: 'p' },
      script: { type: 'string', short: 's' },
      'script-text': { type: 'string', short: 't' },
      timeout: { type: 'string' },
      verbose: { type: 'boolean' },
      help: { type: 'boolean', short: 'h' },
      version: { type: 'boolean', short: 'v' },
      logs: { type: 'boolean' },
    },
    strict: true,
  });

  if (values.help) {
    console.log(HELP);
    process.exit(0);
  }

  if (values.version) {
    const pkgPath = decodeURIComponent(
      path.resolve(
        path.dirname(
          new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/, '$1')
        ),
        '..',
        '..',
        '..',
        'package.json'
      )
    );
    try {
      const pkg = JSON.parse(await fs.readFile(pkgPath, 'utf-8'));
      console.log(pkg.version);
    } catch {
      console.log('unknown');
    }
    process.exit(0);
  }

  if (!values.script && !values['script-text']) {
    OutputHelper.error(
      'Missing required option: --script <file.lua> or --script-text <code>'
    );
    console.log(`\nRun "studio-bridge --help" for usage.`);
    process.exit(1);
  }

  // Suppress verbose output by default; enable with --verbose
  OutputHelper.setVerbose(!!values.verbose);

  const timeoutMs = values.timeout ? parseInt(values.timeout, 10) : 120_000;

  // Resolve place path (optional)
  let placePath: string | undefined;
  if (values.place) {
    placePath = path.resolve(values.place);
    try {
      await fs.access(placePath);
    } catch {
      OutputHelper.error(`Place file not found: ${placePath}`);
      process.exit(1);
    }
  }

  // Resolve script content
  let scriptContent: string;
  if (values['script-text']) {
    scriptContent = values['script-text'];
  } else {
    const scriptPath = path.resolve(values.script!);
    try {
      scriptContent = await fs.readFile(scriptPath, 'utf-8');
    } catch {
      OutputHelper.error(`Could not read script file: ${scriptPath}`);
      process.exit(1);
    }
  }

  // Determine display name for reporting
  const packageName = values.script
    ? path.basename(values.script, path.extname(values.script))
    : 'script';

  const useSpinner = !!process.stdout.isTTY && !values.verbose;
  const showLogs = values.logs ?? true;

  const reporter = new CompositeReporter(
    [packageName],
    (state: LiveStateTracker) => [
      useSpinner
        ? new SpinnerReporter(state, {
            showLogs,
            actionVerb: 'Running',
          })
        : new SimpleReporter(state, {
            alwaysShowLogs: showLogs,
            successMessage: 'Script completed successfully.',
            failureMessage: 'Script failed.',
          }),
    ]
  );

  await reporter.startAsync();
  reporter.onPackageStart(packageName);

  const startTime = performance.now();

  // Suppress verbose output during spinner rendering
  if (useSpinner) {
    OutputHelper.setVerbose(false);
  }

  const server = new StudioBridgeServer({
    placePath,
    timeoutMs,
    onPhase: (phase: StudioBridgePhase) => {
      if (phase === 'done') return;
      reporter.onPackagePhaseChange(packageName, phase);
    },
  });

  const outputLines: string[] = [];
  let result;
  try {
    await server.startAsync();
    result = await server.executeAsync({
      scriptContent,
      onOutput: (level, body) => {
        // Filter internal plugin messages that leak through LogService
        if (body.startsWith('[StudioBridge]')) {
          return;
        }

        // Collect output for the result logs
        outputLines.push(body);

        // In verbose/simple mode, print output in real-time
        if (!useSpinner) {
          switch (level) {
            case 'Warning':
              OutputHelper.warn(body);
              break;
            case 'Error':
              OutputHelper.error(body);
              break;
            default:
              console.log(body);
              break;
          }
        }
      },
    });
  } catch (error) {
    const errorMessage =
      error instanceof Error ? error.message : String(error);
    result = {
      success: false,
      logs: `[StudioBridge] Error: ${errorMessage}`,
    };
  } finally {
    await server.stopAsync();
  }

  const elapsed = performance.now() - startTime;

  reporter.onPackageResult({
    packageName,
    success: result.success,
    logs: outputLines.length > 0 ? outputLines.join('\n') : result.logs,
    durationMs: elapsed,
  });

  await reporter.stopAsync();

  process.exit(result.success ? 0 : 1);
}

main().catch((err) => {
  OutputHelper.error(
    `Fatal: ${err instanceof Error ? err.message : String(err)}`
  );
  process.exit(1);
});
