import * as fs from 'fs';
import * as path from 'path';
import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../args/global-args.js';

interface SourcemapNode {
  name: string;
  className?: string;
  children?: SourcemapNode[];
  filePaths?: string[];
}

interface StripSourcemapJestArgs extends NevermoreGlobalArgs {
  sourcemap?: string;
}

/**
 * Temporary workaround: remove Jest nodes from sourcemap.json.
 *
 * luau-lsp's require-by-name resolution picks the first file matching a name
 * in the sourcemap. Jest vendors internal copies of modules (Promise, string,
 * symbol, etc.) that shadow Nevermore packages. The real loader handles this
 * correctly, but luau-lsp doesn't yet.
 *
 * Long-term fix: smarter require resolution in luau-lsp (plugins or fork).
 */
export const stripSourcemapJestCommand: CommandModule<NevermoreGlobalArgs, StripSourcemapJestArgs> = {
  command: 'strip-sourcemap-jest',
  describe: 'Remove Jest nodes from sourcemap.json to avoid luau-lsp name conflicts',
  builder: (yargs) => {
    return yargs
      .option('sourcemap', {
        describe: 'Path to sourcemap.json',
        type: 'string',
        default: 'sourcemap.json',
      });
  },
  handler: (args) => {
    const sourcemapPath = path.resolve(args.sourcemap!);

    let content: string;
    try {
      content = fs.readFileSync(sourcemapPath, 'utf-8');
    } catch {
      OutputHelper.error(`Sourcemap not found: ${sourcemapPath}`);
      process.exit(1);
    }

    const sourcemap = JSON.parse(content) as SourcemapNode;

    let removed = 0;

    function removeJestNodes(node: SourcemapNode): void {
      if (!node.children) return;

      node.children = node.children.filter((child) => {
        if (child.name === 'Jest') {
          removed++;
          return false;
        }
        return true;
      });

      for (const child of node.children) {
        removeJestNodes(child);
      }
    }

    removeJestNodes(sourcemap);

    fs.writeFileSync(sourcemapPath, JSON.stringify(sourcemap));

    if (removed > 0) {
      OutputHelper.info(`Removed ${removed} Jest node(s) from ${sourcemapPath}`);
    }
  },
};
