import { OutputHelper } from '@quenty/cli-output-helpers';
import { formatCount } from '@quenty/cli-output-helpers/reporting';
import {
  defineCommand,
  type ResultTable,
} from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession } from '../../../bridge/index.js';
import type { GrepMatch } from '../../../server/web-socket-protocol.js';
import {
  formatClassCount,
  formatInstanceTree,
  sharedClassName,
} from '../../shared/instance-tree.js';
import {
  grepTextArgs,
  queryOptionSelectionArgs,
  removedSelectionOptions,
  toInstanceQuery,
  type GrepTextArgs,
  type SelectionArgs,
} from '../selection-args.js';

export interface GrepOptions {
  pattern: string;
  root?: string;
  query?: string;
  selector?: string;
  luaPattern?: boolean;
  caseSensitive?: boolean;
  limit?: number;
}

export interface GrepResult {
  matches: GrepMatch[];
  searched: number;
  total: number;
  scripts: number;
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
    query: options.query,
    selector: options.selector,
    luaPattern: options.luaPattern,
    caseSensitive: options.caseSensitive,
    limit: options.limit,
  });

  const lines = formatCount(result.total, 'matching line', 'matching lines');
  const className = result.truncated
    ? undefined
    : sharedClassName(result.matches);
  const scripts = className
    ? `${formatClassCount(result.scripts, className)} of`
    : `${result.scripts} of`;
  return {
    ...result,
    summary: `${
      result.truncated ? `${result.matches.length} of ${lines}` : lines
    } in ${scripts} ${formatCount(result.searched, 'script', 'scripts')}`,
  };
}

interface ScriptMatches extends GrepMatch {
  lines: GrepMatch[];
}

function groupByScript(matches: GrepMatch[]): ScriptMatches[] {
  const scripts: ScriptMatches[] = [];
  for (const match of matches) {
    const last = scripts[scripts.length - 1];
    if (last && last.path === match.path) {
      last.lines.push(match);
    } else {
      scripts.push({ ...match, lines: [match] });
    }
  }
  return scripts;
}

export function formatGrepText(result: GrepResult): string {
  return formatInstanceTree(groupByScript(result.matches), {
    omitSharedClassName: !result.truncated,
    children: (script) =>
      script.lines.map((m) => ({
        label: `${OutputHelper.formatDim(`${m.line}:`)} ${m.text.trim()}`,
      })),
  });
}

export function toGrepTable(result: GrepResult): ResultTable {
  return {
    columns: ['path', 'className', 'line', 'text'],
    rows: result.matches.map((match) => [
      match.path,
      match.className,
      match.line,
      match.text,
    ]),
  };
}

interface GrepArgs extends SelectionArgs, GrepTextArgs {
  pattern: string;
  limit?: number;
}

export const grepCommand = defineCommand<GrepArgs, GrepResult>({
  group: 'explorer',
  name: 'grep',
  description:
    'Search the source of every script for text, or of the scripts a query or selector picks out',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {
    pattern: arg.positional({
      description: 'Text to find (plain and case-insensitive by default)',
    }),
    ...grepTextArgs,
    ...queryOptionSelectionArgs,
    limit: arg.option({
      description: 'Stop after this many matching lines (default: 200)',
      type: 'number',
      alias: 'n',
    }),
  },
  cli: {
    body: formatGrepText,
    rows: toGrepTable,
    removedOptions: removedSelectionOptions,
  },
  handler: async (session, args) => {
    const { query, selector, root } = toInstanceQuery(args);
    return grepScriptsHandlerAsync(session, {
      pattern: args.pattern,
      query,
      selector,
      root,
      luaPattern: args.luaPattern,
      caseSensitive: args.caseSensitive,
      limit: args.limit,
    });
  },
});
