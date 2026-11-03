/**
 * `explorer grep` — search the source of every script in Studio.
 */

import { OutputHelper } from '@quenty/cli-output-helpers';
import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession } from '../../../bridge/index.js';
import type { GrepMatch } from '../../../server/web-socket-protocol.js';

export interface GrepOptions {
  pattern: string;
  root?: string;
  luaPattern?: boolean;
  caseSensitive?: boolean;
  limit?: number;
}

export interface GrepResult {
  matches: GrepMatch[];
  searched: number;
  /** True when the search stopped at --limit; there may be more. */
  truncated: boolean;
  summary: string;
}

export async function grepScriptsHandlerAsync(
  session: BridgeSession,
  options: GrepOptions
): Promise<GrepResult> {
  const result = await session.grepScriptsAsync({
    pattern: options.pattern,
    root: options.root,
    luaPattern: options.luaPattern,
    caseSensitive: options.caseSensitive,
    limit: options.limit,
  });

  const scripts = new Set(result.matches.map((m) => m.path)).size;
  return {
    ...result,
    summary: result.truncated
      ? `First ${result.matches.length} matching lines; raise --limit to see more`
      : `${result.matches.length} matching line(s) in ${scripts} of ${result.searched} scripts`,
  };
}

/** `path:line: text`, like grep. */
export function formatGrepText(result: GrepResult): string {
  if (result.matches.length === 0) return 'No matches';
  const lines = result.matches.map(
    (m) =>
      `${OutputHelper.formatHint(m.path)}:${OutputHelper.formatDim(
        String(m.line)
      )}: ${m.text.trim()}`
  );
  lines.push(OutputHelper.formatDim(result.summary));
  return lines.join('\n');
}

export const grepCommand = defineCommand<GrepOptions, GrepResult>({
  group: 'explorer',
  name: 'grep',
  description: 'Search the source of every script for text',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {
    pattern: arg.positional({
      description: 'Text to find (plain and case-insensitive by default)',
    }),
    luaPattern: arg.flag({
      description: 'Treat the pattern as a Lua pattern',
    }),
    caseSensitive: arg.flag({
      description: 'Match case',
      alias: 's',
    }),
    root: arg.option({
      description:
        'Dot-separated path to search under (default: the whole DataModel)',
    }),
    limit: arg.option({
      description: 'Stop after this many matching lines (default: 200)',
      type: 'number',
      alias: 'n',
    }),
  },
  cli: {
    format: formatGrepText,
  },
  handler: async (session, args) => grepScriptsHandlerAsync(session, args),
});
