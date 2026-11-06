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
import {
  assertHasCriteria,
  selectionArgs,
  type SelectionArgs,
} from '../selection-args.js';

export interface FindOptions {
  /** Text in the name; any one of them matching is enough. */
  names?: string[];
  /** A single name, as before `names`. */
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
  const selection = assertHasCriteria(
    {
      root: options.root,
      names: options.names,
      name: options.name,
      exactName: options.exact,
      className: options.className,
      tag: options.tag,
    },
    'search for'
  );

  const result = await session.findInstancesAsync({
    ...selection,
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

interface FindArgs extends SelectionArgs {
  limit?: number;
}

export const findCommand = defineCommand<FindArgs, FindResult>({
  group: 'explorer',
  name: 'find',
  description: 'Find instances by name, class or tag',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {
    ...selectionArgs,
    limit: arg.option({
      description: 'Stop after this many matches (default: 200)',
      type: 'number',
      alias: 'n',
    }),
  },
  cli: {
    format: formatFindText,
  },
  handler: async (session, { class: className, ...args }) =>
    findInstancesHandlerAsync(session, { ...args, className }),
});
