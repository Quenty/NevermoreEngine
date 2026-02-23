/**
 * Handler for the `exec` command. Executes inline Luau code in a
 * connected Studio session and returns a structured result.
 */

import type { BridgeSession } from '../bridge/index.js';

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
