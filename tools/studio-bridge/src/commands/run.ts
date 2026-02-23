/**
 * Handler for the `run` command. Reads a Luau script file and executes
 * it in a connected Studio session.
 */

import * as fs from 'fs';
import type { BridgeSession } from '../bridge/index.js';

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
