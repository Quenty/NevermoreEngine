/**
 * `explorer export` — serialize instances from a connected Studio session
 * into a binary model (.rbxm).
 */

import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession } from '../../../bridge/index.js';

export interface ExportResult {
  /** The binary model (.rbxm), base64-encoded. */
  data: string;
  paths: string[];
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
    paths: result.paths,
    bytes,
    summary: `Exported ${
      result.paths.length
    } instance(s) (${bytes} bytes): ${result.paths.join(', ')}`,
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
    format: (result) => result.summary,
  },
  handler: async (session, args) =>
    exportInstancesHandlerAsync(session, args.paths),
});
