/**
 * `console exec` — execute Luau code in a connected Studio session.
 *
 * Accepts inline code (positional), a file path (`--file`), or stdin.
 * This unifies the old `exec` and `run` commands.
 */

import * as fs from 'fs/promises';
import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { resolveScriptContentAsync } from '../../../cli/resolve-script-content.js';
import type { BridgeSession } from '../../../bridge/index.js';

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

/**
 * Execute inline Luau code in a connected Studio session.
 */
export async function execHandlerAsync(
  session: BridgeSession,
  options: ExecOptions
): Promise<ExecResult> {
  const result = await session.execAsync(
    options.scriptContent,
    options.timeout
  );

  const output = (result.output ?? []).map((entry) =>
    typeof entry === 'string' ? entry : entry.body
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
  options: RunOptions
): Promise<RunResult> {
  const scriptContent = await fs.readFile(options.scriptPath, 'utf-8');
  const result = await session.execAsync(scriptContent, options.timeout);

  const output = (result.output ?? []).map((entry) =>
    typeof entry === 'string' ? entry : entry.body
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
    const { scriptContent } = await resolveScriptContentAsync(args);

    return execHandlerAsync(session, {
      scriptContent,
      timeout: args.timeout,
    });
  },
});
