/**
 * Parser for Jest-lua verbose output (`verbose=true, ci=true`).
 *
 * Handles two failure modes:
 *
 * 1. **Jest assertion failures** — `●` blocks:
 *    ```
 *      ● ObservableList > add and remove > should track count
 *
 *        expect(received).toEqual(expected)
 *
 *        Expected: 3
 *        Received: 2
 *
 *          at ServerScriptService.observablecollection.Shared.ObservableList.spec:45
 *    ```
 *
 * 2. **Runtime errors** — `Stack Begin`/`Stack End` blocks:
 *    ```
 *    Error: attempt to index nil with "Connect"
 *    Stack Begin
 *    Script 'ServerScriptService.maid.Shared.Maid.spec', Line 23
 *    Stack End
 *    ```
 *
 * The parser is intentionally lenient — it extracts what it can, skips what
 * it can't, and never crashes on unexpected input.
 */

import * as fs from 'fs';
import { type Diagnostic } from '@quenty/cli-output-helpers/reporting';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { SourcemapResolver } from '../../sourcemap/index.js';
import { resolveRobloxTestPath } from './roblox-path-resolver.js';

/** Matches `at ServerScriptService.pkg.Path.spec:45` (with line number) */
const AT_LOCATION_PATTERN = /^\s+at\s+(.+):(\d+)\s*$/;

/** Matches `at ServerScriptService.pkg.Path.spec` (without line number) */
const AT_LOCATION_NO_LINE_PATTERN = /^\s+at\s+(\S+)\s*$/;

/** Matches `Script 'ServerScriptService.pkg.Path.spec', Line 23` */
const SCRIPT_LOCATION_PATTERN = /Script '([^']+)', Line (\d+)/;

/** Matches the Jest failure header: `● TestSuite > nested > test name` */
const FAILURE_HEADER_PATTERN = /^\s*●\s+(.+)$/;

const enum State {
  IDLE,
  FAILURE_BLOCK,
  STACK_BLOCK,
}

interface FailureContext {
  title: string;
  messageLines: string[];
  file?: string;
  line?: number;
}

interface StackContext {
  errorMessage: string;
  file?: string;
  line?: number;
}

/**
 * Search a `.spec.lua` file for an `it()` call matching `testName`.
 * Returns the 1-indexed line number, or `undefined` if not found.
 */
function _findTestLineInFile(
  filePath: string,
  testName: string
): number | undefined {
  let content: string;
  try {
    content = fs.readFileSync(filePath, 'utf-8');
  } catch {
    return undefined;
  }

  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    if (
      lines[i].includes(`it("${testName}"`) ||
      lines[i].includes(`it('${testName}'`)
    ) {
      return i + 1;
    }
  }

  return undefined;
}

/**
 * Parse Jest-lua verbose output into `Diagnostic[]`.
 *
 * @param raw - Raw test output (may include ANSI codes)
 * @param options.packageName - Package name for fallback path resolution
 */
export function parseJestLuaOutput(
  raw: string,
  options: { packageName: string; sourcemapResolver?: SourcemapResolver }
): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];
  const clean = OutputHelper.stripAnsi(raw);
  const lines = clean.split('\n');

  let state: State = State.IDLE;
  let failureCtx: FailureContext | undefined;
  let stackCtx: StackContext | undefined;
  let lastNonEmptyLine = '';

  function _emitFailure(ctx: FailureContext): void {
    const message = ctx.messageLines
      .join('\n')
      .trim();

    // 3-tier line resolution:
    //  1. Primary: line number extracted from `at <path>:<line>` or similar
    //  2. Secondary: search the resolved .spec.lua file for the it() call
    //  3. Tertiary: fall back to line 1
    let file: string;
    let line: number;

    if (ctx.file) {
      file = resolveRobloxTestPath(ctx.file, options.sourcemapResolver);

      if (ctx.line) {
        line = ctx.line;
      } else {
        const segments = ctx.title.split(' > ');
        const testName = segments[segments.length - 1].trim();
        line = _findTestLineInFile(file, testName) ?? 1;
      }
    } else {
      file = `src/${options.packageName}/src`;
      line = 1;
    }

    diagnostics.push({
      file,
      line,
      severity: 'error',
      title: ctx.title,
      message: message || 'Test failed',
      source: 'jest-lua',
    });
  }

  function _emitStack(ctx: StackContext): void {
    const file = ctx.file
      ? resolveRobloxTestPath(ctx.file, options.sourcemapResolver)
      : `src/${options.packageName}/src`;
    const line = ctx.line ?? 1;

    diagnostics.push({
      file,
      line,
      severity: 'error',
      title: 'Runtime error',
      message: ctx.errorMessage || 'Unknown runtime error',
      source: 'jest-lua',
    });
  }

  for (const rawLine of lines) {
    switch (state) {
      case State.IDLE: {
        const failureMatch = rawLine.match(FAILURE_HEADER_PATTERN);
        if (failureMatch) {
          failureCtx = {
            title: failureMatch[1].trim(),
            messageLines: [],
          };
          state = State.FAILURE_BLOCK;
          break;
        }

        if (rawLine.trim() === 'Stack Begin') {
          stackCtx = {
            errorMessage: lastNonEmptyLine,
          };
          state = State.STACK_BLOCK;
          break;
        }

        if (rawLine.trim() !== '') {
          lastNonEmptyLine = rawLine.trim();
        }
        break;
      }

      case State.FAILURE_BLOCK: {
        if (!failureCtx) {
          state = State.IDLE;
          break;
        }

        const atMatch = rawLine.match(AT_LOCATION_PATTERN);
        if (atMatch) {
          failureCtx.file = atMatch[1];
          failureCtx.line = parseInt(atMatch[2], 10);
          _emitFailure(failureCtx);
          failureCtx = undefined;
          state = State.IDLE;
          break;
        }

        const atNoLineMatch = rawLine.match(AT_LOCATION_NO_LINE_PATTERN);
        if (atNoLineMatch) {
          failureCtx.file = atNoLineMatch[1];
          _emitFailure(failureCtx);
          failureCtx = undefined;
          state = State.IDLE;
          break;
        }

        const nextFailure = rawLine.match(FAILURE_HEADER_PATTERN);
        if (nextFailure) {
          _emitFailure(failureCtx);
          failureCtx = {
            title: nextFailure[1].trim(),
            messageLines: [],
          };
          break;
        }

        if (rawLine.trim() === 'Stack Begin') {
          _emitFailure(failureCtx);
          stackCtx = {
            errorMessage: failureCtx.messageLines.length > 0
              ? failureCtx.messageLines[failureCtx.messageLines.length - 1].trim()
              : failureCtx.title,
          };
          failureCtx = undefined;
          state = State.STACK_BLOCK;
          break;
        }

        failureCtx.messageLines.push(rawLine);
        break;
      }

      case State.STACK_BLOCK: {
        if (!stackCtx) {
          state = State.IDLE;
          break;
        }

        const scriptMatch = rawLine.match(SCRIPT_LOCATION_PATTERN);
        if (scriptMatch) {
          stackCtx.file = scriptMatch[1];
          stackCtx.line = parseInt(scriptMatch[2], 10);
          break;
        }

        if (rawLine.trim() === 'Stack End') {
          _emitStack(stackCtx);
          stackCtx = undefined;
          state = State.IDLE;
          break;
        }

        break;
      }
    }
  }

  // Flush any pending context at end of input
  if (failureCtx && state === State.FAILURE_BLOCK) {
    _emitFailure(failureCtx);
  }
  if (stackCtx && state === State.STACK_BLOCK) {
    _emitStack(stackCtx);
  }

  return diagnostics;
}
