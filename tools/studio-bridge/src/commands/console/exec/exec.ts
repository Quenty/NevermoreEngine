/**
 * `console exec` — execute Luau code in a connected Studio session.
 *
 * Accepts inline code (positional), a file path (`--file`), or stdin.
 * This unifies the old `exec` and `run` commands.
 */

import * as fs from 'fs';
import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession } from '../../../bridge/index.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ExecOptions {
  scriptContent: string;
  timeout?: number;
}

export interface ExecResult {
  success: boolean;
  output: string[];
  error?: string;
  summary: string;
}

export interface RunOptions {
  scriptPath: string;
  timeout?: number;
}

export interface RunResult {
  success: boolean;
  output: string[];
  error?: string;
  summary: string;
}

interface ConsoleExecArgs {
  code?: string;
  file?: string;
  timeout?: number;
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

/**
 * Execute inline Luau code in a connected Studio session.
 */
export async function execHandlerAsync(
  session: BridgeSession,
  options: ExecOptions,
): Promise<ExecResult> {
  const result = await session.execAsync(options.scriptContent, options.timeout);

  const output = (result.output ?? []).map((entry) =>
    typeof entry === 'string' ? entry : entry.body,
  );

  return {
    success: result.success,
    output,
    error: result.error,
    summary: result.success
      ? 'Script executed successfully'
      : `Script failed: ${result.error}`,
  };
}

/**
 * Read a Luau script file and execute it in a connected Studio session.
 */
export async function runHandlerAsync(
  session: BridgeSession,
  options: RunOptions,
): Promise<RunResult> {
  const scriptContent = fs.readFileSync(options.scriptPath, 'utf-8');
  const result = await session.execAsync(scriptContent, options.timeout);

  const output = (result.output ?? []).map((entry) =>
    typeof entry === 'string' ? entry : entry.body,
  );

  return {
    success: result.success,
    output,
    error: result.error,
    summary: result.success
      ? `Script ${options.scriptPath} executed successfully`
      : `Script ${options.scriptPath} failed: ${result.error}`,
  };
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const execCommand = defineCommand<ConsoleExecArgs, ExecResult>({
  group: 'console',
  name: 'exec',
  description: 'Execute Luau code in a connected Studio session',
  category: 'execution',
  safety: 'mutate',
  scope: 'session',
  args: {
    code: arg.positional({
      description: 'Inline Luau code to execute',
      required: false,
    }),
    file: arg.option({
      description: 'Path to a Luau script file to execute',
      alias: 'f',
    }),
    timeout: arg.option({
      description: 'Execution timeout in milliseconds',
      type: 'number',
    }),
  },
  cli: {
    formatResult: {
      text: (result) => {
        const lines = result.output.join('\n');
        if (result.error) return lines + (lines ? '\n' : '') + result.error;
        return lines || result.summary;
      },
      table: (result) => {
        const lines = result.output.join('\n');
        if (result.error) return lines + (lines ? '\n' : '') + result.error;
        return lines || result.summary;
      },
    },
  },
  handler: async (session, args) => {
    let scriptContent: string;

    if (args.file) {
      scriptContent = fs.readFileSync(args.file, 'utf-8');
    } else if (args.code) {
      scriptContent = args.code;
    } else {
      throw new Error(
        'Either inline code or --file must be provided',
      );
    }

    return execHandlerAsync(session, {
      scriptContent,
      timeout: args.timeout,
    });
  },
  mcp: {
    mapInput: (input) => ({
      code: input.code as string | undefined,
      file: input.file as string | undefined,
      timeout: input.timeout as number | undefined,
    }),
    mapResult: (result) => [
      {
        type: 'text' as const,
        text: JSON.stringify({
          success: result.success,
          output: result.output,
          error: result.error,
        }),
      },
    ],
  },
});
