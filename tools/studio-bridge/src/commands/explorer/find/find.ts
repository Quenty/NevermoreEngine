import { formatCount } from '@quenty/cli-output-helpers/reporting';
import {
  defineCommand,
  type ResultTable,
} from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession, InstanceRef } from '../../../bridge/index.js';
import {
  formatClassCount,
  formatInstanceTree,
  sharedClassName,
} from '../../shared/instance-tree.js';
import {
  assertHasCriteria,
  grepSelectionArgs,
  removedSelectionOptions,
  toInstanceQuery,
  type GrepSelectionArgs,
  type InstanceQuery,
  type SelectionArgs,
} from '../selection-args.js';

export interface FindOptions extends InstanceQuery {
  limit?: number;
}

export interface FindResult {
  instances: InstanceRef[];
  searched: number;
  total: number;
  truncated: boolean;
  summary: string;
}

export async function findInstancesHandlerAsync(
  session: BridgeSession,
  options: FindOptions
): Promise<FindResult> {
  assertHasCriteria(options, 'search for', { grep: true });

  const result = await session.findInstancesAsync(options);

  const className = result.truncated
    ? undefined
    : sharedClassName(result.instances);
  const matches = className
    ? formatClassCount(result.total, className)
    : formatCount(result.total, 'match', 'matches');
  return {
    ...result,
    summary: `${
      result.truncated ? `${result.instances.length} of ${matches}` : matches
    } among ${formatCount(result.searched, 'instance', 'instances')}`,
  };
}

export function toFindTable(result: FindResult): ResultTable {
  return {
    columns: ['path', 'className'],
    rows: result.instances.map((instance) => [
      instance.path,
      instance.className,
    ]),
  };
}

interface FindArgs extends SelectionArgs, GrepSelectionArgs {
  limit?: number;
}

export const findCommand = defineCommand<FindArgs, FindResult>({
  group: 'explorer',
  name: 'find',
  description:
    'Find instances with Roblox Explorer search syntax, a QueryDescendants selector or script source text',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {
    ...grepSelectionArgs,
    limit: arg.option({
      description: 'Stop after this many matches (default: 200)',
      type: 'number',
      alias: 'n',
    }),
  },
  cli: {
    body: (result) =>
      formatInstanceTree(result.instances, {
        omitSharedClassName: !result.truncated,
      }),
    rows: toFindTable,
    removedOptions: removedSelectionOptions,
  },
  handler: async (session, args) =>
    findInstancesHandlerAsync(session, {
      ...toInstanceQuery(args),
      limit: args.limit,
    }),
});
