/**
 * `process run` -- explicit ephemeral mode: launch Studio, execute code,
 * then tear down. Wraps the StudioBridgeServer lifecycle with full
 * reporter output.
 *
 * This is standalone (no existing connection needed) and is CLI-only.
 * MCP does NOT expose this command.
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ProcessRunOptions {
  scriptContent: string;
  packageName: string;
  placePath?: string;
  timeoutMs: number;
  verbose: boolean;
  showLogs: boolean;
}

export interface ProcessRunResult {
  success: boolean;
  summary: string;
}

interface ProcessRunArgs {
  code?: string;
  file?: string;
  place?: string;
  timeout?: number;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/**
 * Run an ephemeral Studio process, execute a script, and shut down.
 * Delegates to `executeScriptAsync` from the script-executor module.
 */
export async function processRunHandlerAsync(
  options: ProcessRunOptions,
): Promise<ProcessRunResult> {
  // Lazy import to avoid pulling in StudioBridgeServer at module load
  const { executeScriptAsync } = await import('../../../cli/script-executor.js');

  // executeScriptAsync calls process.exit internally, so this return
  // is only reachable in test scenarios where it's mocked.
  await executeScriptAsync(options);

  return {
    success: true,
    summary: 'Script execution completed.',
  };
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const processRunCommand = defineCommand<ProcessRunArgs, ProcessRunResult>({
  group: 'process',
  name: 'run',
  description: 'Launch Studio, execute a script, and shut down (ephemeral mode)',
  category: 'execution',
  safety: 'none',
  scope: 'standalone',
  args: {
    code: arg.positional({
      description: 'Inline Luau code to execute',
      required: false,
    }),
    file: arg.option({
      description: 'Path to a Luau script file to execute',
      alias: 'f',
    }),
    place: arg.option({
      description: 'Path to a .rbxl place file',
      alias: 'p',
    }),
    timeout: arg.option({
      description: 'Execution timeout in milliseconds',
      type: 'number',
    }),
  },
  handler: async (args) => {
    const fs = await import('fs');

    let scriptContent: string;
    if (args.file) {
      scriptContent = fs.readFileSync(args.file, 'utf-8');
    } else if (args.code) {
      scriptContent = args.code;
    } else {
      throw new Error('Either inline code or --file must be provided');
    }

    return processRunHandlerAsync({
      scriptContent,
      packageName: 'studio-bridge',
      placePath: args.place,
      timeoutMs: args.timeout ?? 120_000,
      verbose: false,
      showLogs: true,
    });
  },
  // No MCP config -- process run is CLI-only
});
