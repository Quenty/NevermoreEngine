import { arg, type ArgDefinition } from '../framework/arg-builder.js';
import type { InstanceQuery } from '../../server/web-socket-protocol.js';
import { invalidInput } from '../../messages/studio-bridge-error.js';

export type { InstanceQuery };

const QUERY_DESCRIPTION =
  'Roblox Explorer search: a name (case-insensitive, partial), is:Class, tag:Tag, Prop=value (also ~= < > <= >=), Parent.Child paths with * and **, combined with spaces/and, or, and parentheses';

export interface SelectionArgs {
  query?: string | string[];
  selector?: string;
  root?: string;
}

export interface GrepTextArgs {
  luaPattern?: boolean;
  caseSensitive?: boolean;
}

export interface GrepSelectionArgs extends GrepTextArgs {
  grep?: string;
}

const selectorArg = arg.option({
  description:
    'Instance:QueryDescendants selector, run from the root (e.g. "Model > BasePart")',
});

const rootArg = arg.option({
  description:
    'What to search under: a full path from game (Workspace.Map) or a query matching exactly one instance (_Index, "pkg@1.2.3"). Default: the whole DataModel',
});

export const grepTextArgs: Record<keyof GrepTextArgs, ArgDefinition> = {
  luaPattern: arg.flag({
    description: 'Treat the grep text as a Lua pattern',
  }),
  caseSensitive: arg.flag({
    description: 'Match the grep text with case',
    alias: 's',
  }),
};

export const selectionArgs: Record<keyof SelectionArgs, ArgDefinition> = {
  query: arg.positional({
    description: QUERY_DESCRIPTION,
    required: false,
    array: true,
  }),
  selector: selectorArg,
  root: rootArg,
};

export const grepSelectionArgs: Record<
  keyof (SelectionArgs & GrepSelectionArgs),
  ArgDefinition
> = {
  ...selectionArgs,
  grep: arg.option({
    description:
      'Only scripts whose source contains this text (plain and case-insensitive by default)',
  }),
  ...grepTextArgs,
};

export const queryOptionSelectionArgs: Record<
  keyof SelectionArgs,
  ArgDefinition
> = {
  query: arg.option({ description: QUERY_DESCRIPTION }),
  selector: selectorArg,
  root: rootArg,
};

export const removedSelectionOptions: Record<string, string> = {
  class: 'Put is:Part in the query instead.',
  tag: 'Put tag:Door in the query instead.',
  exact:
    'Put a path in the query instead, e.g. *.Door, which matches whole names.',
};

export function toInstanceQuery(
  args: SelectionArgs & GrepSelectionArgs
): InstanceQuery {
  return {
    root: args.root,
    query: joinQuery(args.query),
    selector: nonEmpty(args.selector),
    grep: nonEmpty(args.grep),
    luaPattern: args.luaPattern || undefined,
    caseSensitive: args.caseSensitive || undefined,
  };
}

export function assertHasCriteria(
  query: InstanceQuery,
  verb: string,
  options: { grep?: boolean } = {}
): void {
  if (!query.query && !query.selector && !query.grep) {
    const flags = options.grep ? ', --selector or --grep' : ' or --selector';
    throw invalidInput(
      `Nothing to ${verb}: no query was given.`,
      `Give a query${flags}, e.g. is:Part.`
    );
  }
}

function joinQuery(query: string | string[] | undefined): string | undefined {
  if (query === undefined) return undefined;
  return nonEmpty([query].flat().join(' '));
}

function nonEmpty(value: string | undefined): string | undefined {
  return value !== undefined && value.trim() !== '' ? value : undefined;
}
