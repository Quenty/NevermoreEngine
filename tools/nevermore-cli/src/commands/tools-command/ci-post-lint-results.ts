import * as fs from 'fs/promises';
import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  emitAnnotations,
  writeAnnotationSummaryAsync,
} from '@quenty/cli-output-helpers/reporting';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import {
  LINTER_PARSERS,
  LINTER_DISPLAY_NAMES,
  SUPPORTED_LINTERS,
} from '../../utils/linting/parsers/index.js';

interface CiPostLintResultsArgs extends NevermoreGlobalArgs {
  input: string;
  linter: string;
}

export const ciPostLintResultsCommand: CommandModule<
  NevermoreGlobalArgs,
  CiPostLintResultsArgs
> = {
  command: 'post-lint-results <input>',
  describe:
    'Parse linter output and emit GitHub Actions annotations (requires CI context)',
  builder: (yargs) => {
    return yargs
      .positional('input', {
        describe: 'Path to captured linter output file',
        type: 'string',
        demandOption: true,
      })
      .option('linter', {
        describe: 'Which linter produced the output',
        type: 'string',
        choices: SUPPORTED_LINTERS,
        demandOption: true,
      });
  },
  handler: async (args) => {
    try {
      const parser = LINTER_PARSERS[args.linter];
      if (!parser) {
        OutputHelper.error(
          `Unknown linter: ${args.linter}. Supported: ${SUPPORTED_LINTERS.join(', ')}`
        );
        process.exit(1);
      }

      let raw: string;
      try {
        raw = await fs.readFile(args.input, 'utf-8');
      } catch {
        OutputHelper.warn(`Lint output file not found: ${args.input}`);
        return;
      }

      const displayName =
        LINTER_DISPLAY_NAMES[args.linter] ?? args.linter;
      const diagnostics = parser(raw);

      if (diagnostics.length === 0) {
        OutputHelper.info(
          `${displayName}: no issues found in lint output.`
        );
        return;
      }

      OutputHelper.info(
        `${displayName}: found ${diagnostics.length} issue(s). Emitting annotations...`
      );

      emitAnnotations(diagnostics);
      await writeAnnotationSummaryAsync(displayName, diagnostics);
    } catch (err) {
      OutputHelper.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
    }
  },
};
