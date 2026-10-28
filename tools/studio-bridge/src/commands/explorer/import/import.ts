/**
 * `explorer import` — insert a binary model (.rbxm) into a connected Studio
 * session.
 */

import * as fs from 'fs/promises';
import { defineCommand } from '../../framework/define-command.js';
import { arg } from '../../framework/arg-builder.js';
import type { BridgeSession } from '../../../bridge/index.js';

export interface ImportResult {
  paths: string[];
  summary: string;
}

export interface ImportOptions {
  file: string;
  parent?: string;
}

interface ImportArgs {
  file: string;
  parent?: string;
}

export async function importInstancesHandlerAsync(
  session: BridgeSession,
  options: ImportOptions
): Promise<ImportResult> {
  const data = await fs.readFile(options.file);
  const result = await session.importInstancesAsync(
    data.toString('base64'),
    options.parent ?? 'Workspace'
  );

  return {
    paths: result.paths,
    summary: `Imported ${result.paths.length} instance(s): ${result.paths.join(
      ', '
    )}`,
  };
}

export const importCommand = defineCommand<ImportArgs, ImportResult>({
  group: 'explorer',
  name: 'import',
  description: 'Insert a binary model (.rbxm) into Studio',
  category: 'execution',
  safety: 'mutate',
  changesDataModel: true,
  scope: 'session',
  args: {
    file: arg.positional({
      description: 'Path to a .rbxm file',
    }),
    parent: arg.option({
      description:
        'Dot-separated path of the parent instance (default: Workspace)',
    }),
  },
  handler: async (session, args) =>
    importInstancesHandlerAsync(session, {
      file: args.file,
      parent: args.parent,
    }),
});
