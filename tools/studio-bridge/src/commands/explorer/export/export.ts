/**
 * `explorer export` — serialize instances from a connected Studio session
 * into a binary model (.rbxm).
 */

import { formatCount } from '@quenty/cli-output-helpers/reporting';
import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession, InstanceRef } from '../../../bridge/index.js';
import { formatInstanceTree } from '../../shared/instance-tree.js';

export interface ExportResult {
  /** The binary model (.rbxm), base64-encoded. */
  data: string;
  instances: InstanceRef[];
  bytes: number;
  summary: string;
}

interface ExportArgs {
  paths: string[];
}

export async function exportInstancesHandlerAsync(
  session: BridgeSession,
  paths: string[]
): Promise<ExportResult> {
  const result = await session.exportInstancesAsync(paths);
  const bytes = Buffer.from(result.data, 'base64').length;

  return {
    data: result.data,
    instances: result.instances,
    bytes,
    summary: `Exported ${formatCount(
      result.instances.length,
      'instance',
      'instances'
    )} (${formatCount(bytes, 'byte', 'bytes')})`,
  };
}

export const exportCommand = defineCommand<ExportArgs, ExportResult>({
  group: 'explorer',
  name: 'export',
  description:
    'Save instances from Studio as a binary model (.rbxm). Use -o to write the file.',
  category: 'execution',
  safety: 'read',
  scope: 'session',
  args: {
    paths: arg.positional({
      description: 'Dot-separated instance paths (e.g. Workspace.Map)',
      required: true,
      array: true,
    }),
  },
  cli: {
    binaryField: 'data',
    body: (result) => formatInstanceTree(result.instances),
  },
  handler: async (session, args) =>
    exportInstancesHandlerAsync(session, args.paths),
});
