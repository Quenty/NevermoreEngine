/**
 * Shared parsing for commands that accept either inline Luau code or a
 * file path. Used by `console exec` and `process run`.
 */

import * as fs from 'fs/promises';
import * as path from 'path';

export interface ScriptContentArgs {
  code?: string;
  file?: string;
}

export interface ResolvedScriptContent {
  scriptContent: string;
  /** Absolute path of the resolved file, or undefined when using inline code. */
  filePath?: string;
}

/**
 * Reads inline code or a file (resolved against CWD) into a string.
 * Throws if neither is provided.
 */
export async function resolveScriptContentAsync(
  args: ScriptContentArgs
): Promise<ResolvedScriptContent> {
  if (args.file) {
    const absolutePath = path.resolve(args.file);
    const scriptContent = await fs.readFile(absolutePath, 'utf-8');
    return { scriptContent, filePath: absolutePath };
  }
  if (args.code) {
    return { scriptContent: args.code };
  }
  throw new Error('Either inline code or --file must be provided');
}
