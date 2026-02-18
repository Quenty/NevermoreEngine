/**
 * Linter parser registry.
 *
 * Each parser converts raw linter output into a `Diagnostic[]` array
 * suitable for GitHub Actions annotations.
 */

import { type Diagnostic } from '@quenty/cli-output-helpers/reporting';
import { parseLuauLspOutput } from './luau-lsp-parser.js';
import { parseStyluaOutput } from './stylua-parser.js';
import { parseSeleneOutput } from './selene-parser.js';
import { parseMoonwaveOutput } from './moonwave-parser.js';

export type LinterParser = (raw: string) => Diagnostic[];

export const LINTER_PARSERS: Record<string, LinterParser> = {
  'luau-lsp': parseLuauLspOutput,
  stylua: parseStyluaOutput,
  selene: parseSeleneOutput,
  moonwave: parseMoonwaveOutput,
};

export const LINTER_DISPLAY_NAMES: Record<string, string> = {
  'luau-lsp': 'luau-lsp',
  stylua: 'StyLua',
  selene: 'Selene',
  moonwave: 'Moonwave',
};

export const SUPPORTED_LINTERS = Object.keys(LINTER_PARSERS);
