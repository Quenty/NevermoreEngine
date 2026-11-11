/**
 * Shared parsing for commands that accept either inline Luau code or a
 * file path. Used by `console exec` and `process run`.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import {
  invalidInput,
  StudioBridgeError,
} from '../messages/studio-bridge-error.js';

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
    const scriptContent = await fs
      .readFile(absolutePath, 'utf-8')
      .catch((cause: unknown) => {
        throw new StudioBridgeError({
          code: 'INVALID_INPUT',
          message: `Can't read --file '${args.file}'.`,
          fix: 'Check the path, then run the command again.',
          cause,
        });
      });
    return { scriptContent, filePath: absolutePath };
  }
  if (args.code) {
    return { scriptContent: args.code };
  }
  throw invalidInput(
    'No code to run.',
    "Give the code inline, e.g. 'return 1 + 1', or pass --file."
  );
}
