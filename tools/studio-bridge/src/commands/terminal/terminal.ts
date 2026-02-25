/**
 * `terminal` -- interactive REPL mode for executing Luau scripts
 * repeatedly in a persistent Studio session.
 *
 * This is a standalone command with a custom CLI handler escape hatch:
 * the terminal REPL lifecycle is inherently interactive and cannot be
 * expressed as a simple `(args) => Promise<TResult>` handler. The
 * `defineCommand` wrapper is used for registry/help grouping only.
 */

import { defineCommand } from '../framework/define-command.js';
import { arg } from '../framework/arg-builder.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface TerminalOptions {
  placePath?: string;
  scriptPath?: string;
  scriptText?: string;
  timeoutMs: number;
  verbose: boolean;
}

export interface TerminalResult {
  summary: string;
}

interface TerminalArgs {
  script?: string;
  'script-text'?: string;
}

// ---------------------------------------------------------------------------
// Command definition
// ---------------------------------------------------------------------------

export const terminalCommand = defineCommand<TerminalArgs, TerminalResult>({
  group: null,
  name: 'terminal',
  description:
    'Interactive terminal mode -- keep Studio alive and execute scripts via REPL',
  category: 'infrastructure',
  safety: 'none',
  scope: 'standalone',
  args: {
    script: arg.option({
      description: 'Path to a Luau script to run on connect',
      alias: 's',
    }),
    'script-text': arg.option({
      description: 'Inline Luau code to run on connect',
      alias: 't',
    }),
  },
  handler: async () => {
    // The terminal REPL is started by the CLI command handler directly,
    // not through this handler. This stub exists so the command appears
    // in the registry for help grouping and MCP exclusion.
    return { summary: 'Terminal mode is CLI-only.' };
  },
  // No MCP config -- terminal is CLI-only
});
