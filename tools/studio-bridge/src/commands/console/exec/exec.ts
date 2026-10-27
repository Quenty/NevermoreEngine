/**
 * `console exec` — execute Luau code in a connected Studio session.
 *
 * Accepts inline code (positional), a file path (`--file`), or stdin.
 * This unifies the old `exec` and `run` commands.
 */

import * as fs from 'fs/promises';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import { resolveScriptContentAsync } from '../../../cli/resolve-script-content.js';
import type { BridgeSession } from '../../../bridge/index.js';
import type { SerializedReturnValue } from '../../../server/web-socket-protocol.js';

export interface ExecOptions {
  scriptContent: string;
  timeout?: number;
}

export interface ExecResult {
  success: boolean;
  output: string[];
  error?: string;
  traceback?: string;
  returnValues?: SerializedReturnValue[];
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
  traceback?: string;
  returnValues?: SerializedReturnValue[];
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
    traceback: result.traceback,
    returnValues: result.returnValues,
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
    traceback: result.traceback,
    returnValues: result.returnValues,
    summary: result.success
      ? `Script ${options.scriptPath} executed successfully`
      : `Script ${options.scriptPath} failed: ${result.error}`,
  };
}

export function formatReturnValues(
  returnValues: SerializedReturnValue[]
): string {
  return returnValues
    .map((value) => {
      if (typeof value === 'string') return value;
      if (
        typeof value === 'object' &&
        value !== null &&
        !Array.isArray(value) &&
        value.type === 'Nil'
      ) {
        return 'nil';
      }
      return JSON.stringify(value);
    })
    .join('\t');
}

/** Render an exec result as its output, then its return values, then its error. */
export function formatExecText(result: {
  output: string[];
  returnValues?: SerializedReturnValue[];
  error?: string;
  traceback?: string;
  summary: string;
}): string {
  const lines = [...result.output];
  if (result.returnValues && result.returnValues.length > 0) {
    lines.push(formatReturnValues(result.returnValues));
  }
  if (result.error) lines.push(result.error);
  if (result.traceback)
    lines.push(OutputHelper.formatDim(result.traceback.trimEnd()));
  return lines.length > 0 ? lines.join('\n') : result.summary;
}

export const execCommand = defineCommand<ConsoleExecArgs, ExecResult>({
  group: 'console',
  name: 'exec',
  description: 'Execute Luau code in a connected Studio session',
  category: 'execution',
  safety: 'mutate',
  changesDataModel: true,
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
    format: formatExecText,
  },
  handler: async (session, args) => {
    const { scriptContent } = await resolveScriptContentAsync(args);

    return execHandlerAsync(session, {
      scriptContent,
      timeout: args.timeout,
    });
  },
});
