/**
 * `explorer find` — search the DataModel for instances by name, class and tag.
 */

import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  formatTable,
  type TableColumn,
} from '@quenty/cli-output-helpers/reporting';
import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession } from '../../../bridge/index.js';
import type { FoundInstance } from '../../../server/web-socket-protocol.js';

export interface FindOptions {
  name?: string;
  exact?: boolean;
  className?: string;
  tag?: string;
  root?: string;
  limit?: number;
}

export interface FindResult {
  instances: FoundInstance[];
  searched: number;
  /** True when the search stopped at --limit; there may be more. */
  truncated: boolean;
  summary: string;
}

export async function findInstancesHandlerAsync(
  session: BridgeSession,
  options: FindOptions
): Promise<FindResult> {
  if (!options.name && !options.className && !options.tag) {
    throw new Error('Give a name, --class or --tag to search for');
  }

  const result = await session.findInstancesAsync({
    root: options.root,
    name: options.name,
    exactName: options.exact,
    className: options.className,
    tag: options.tag,
    limit: options.limit,
  });

  return {
    ...result,
    summary: result.truncated
      ? `First ${result.instances.length} matches; raise --limit to see more`
      : `${result.instances.length} match(es) among ${result.searched} instances`,
  };
}

const columns: TableColumn<FoundInstance>[] = [
  {
    header: 'Path',
    value: (i) => i.path,
    format: (v) => OutputHelper.formatHint(v),
  },
  { header: 'Class', value: (i) => i.className },
];

export function formatFindText(result: FindResult): string {
  if (result.instances.length === 0) return 'No instances match';
  return `${formatTable(result.instances, columns)}\n${OutputHelper.formatDim(
    result.summary
  )}`;
}

interface FindArgs extends Omit<FindOptions, 'className'> {
  class?: string;
}

export const findCommand = defineCommand<FindArgs, FindResult>({
  group: 'explorer',
  name: 'find',
  description: 'Find instances by name, class or tag',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {
    name: arg.positional({
      description: 'Text in the instance name (case-insensitive)',
      required: false,
    }),
    exact: arg.flag({
      description: 'Match the whole name instead of part of it',
    }),
    class: arg.option({
      description: 'Only instances of this class or a subclass (IsA)',
      alias: 'c',
    }),
    tag: arg.option({
      description: 'Only instances with this CollectionService tag',
    }),
    root: arg.option({
      description:
        'Dot-separated path to search under (default: the whole DataModel)',
    }),
    limit: arg.option({
      description: 'Stop after this many matches (default: 200)',
      type: 'number',
    }),
  },
  cli: {
    format: formatFindText,
  },
  handler: async (session, { class: className, ...args }) =>
    findInstancesHandlerAsync(session, { ...args, className }),
});
