import * as fs from 'fs';
import * as path from 'path';
import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import type { SourcemapNode } from '../../utils/sourcemap/index.js';

interface StripSourcemapJestArgs extends NevermoreGlobalArgs {
  sourcemap?: string;
}

/**
 * Temporary workaround: strip shadowing modules from Jest subtrees in sourcemap.json.
 *
 * luau-lsp's require-by-name resolution picks the first file matching a name
 * in the sourcemap. Jest vendors internal copies of modules (Promise, string,
 * symbol, etc.) that shadow Nevermore packages. The real loader handles this
 * correctly, but luau-lsp doesn't yet.
 *
 * We drop only the Jest descendants whose name also exists elsewhere in the
 * sourcemap (the shadowing copies), and keep the Jest-unique modules (Jest,
 * JestGlobals, ...) so `require("Jest")` still resolves.
 *
 * Long-term fix: smarter require resolution in luau-lsp (plugins or fork).
 */
export const stripSourcemapJestCommand: CommandModule<
  NevermoreGlobalArgs,
  StripSourcemapJestArgs
> = {
  command: 'strip-sourcemap-jest',
  describe:
    "Strip modules from Jest subtrees in sourcemap.json that shadow names elsewhere, keeping require('Jest') resolvable",
  builder: (yargs) => {
    return yargs.option('sourcemap', {
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

    // Every module name that lives OUTSIDE any Jest subtree. Jest's vendored copies of these
    // are what shadow the real Nevermore modules under luau-lsp's first-match resolution.
    const externalNames = new Set<string>();
    function collectExternalNames(
      node: SourcemapNode,
      insideJest: boolean
    ): void {
      if (!node.children) return;
      for (const child of node.children) {
        const childInsideJest = insideJest || child.name === 'Jest';
        if (!childInsideJest) {
          externalNames.add(child.name);
        }
        collectExternalNames(child, childInsideJest);
      }
    }
    collectExternalNames(sourcemap, false);

    // Within each Jest subtree, drop any node whose name also exists elsewhere (the shadowing
    // copies), keeping the Jest-unique modules so require("Jest") still resolves. Also drop a
    // Jest node nested inside another Jest: the jest-lua package folder ("Jest", whose
    // init.lua exports `.Globals`) contains a leaf "Jest" submodule that lacks `.Globals`, and
    // the duplicate name makes require("Jest") resolve to the wrong one for some packages.
    let stripped = 0;
    function stripShadowingNodes(
      node: SourcemapNode,
      insideJest: boolean
    ): void {
      if (!node.children) return;

      if (insideJest) {
        node.children = node.children.filter((child) => {
          if (externalNames.has(child.name) || child.name === 'Jest') {
            stripped++;
            return false;
          }
          return true;
        });
      }

      for (const child of node.children) {
        stripShadowingNodes(child, insideJest || child.name === 'Jest');
      }
    }
    stripShadowingNodes(sourcemap, false);

    fs.writeFileSync(sourcemapPath, JSON.stringify(sourcemap));

    if (stripped > 0) {
      OutputHelper.info(
        `Stripped ${stripped} shadowing node(s) from Jest subtrees in ${sourcemapPath}`
      );
    }
  },
};
