/**
 * Parser for Jest-lua verbose output (`verbose=true, ci=true`).
 *
 * Emits one diagnostic per `●` failure block and per `Stack Begin`/`Stack End`
 * runtime error, at the innermost frame that resolves to a repo file,
 * preferring the package under test. Diagnostics with no resolvable frame
 * carry no file. Unexpected input is skipped, never thrown on.
 */

import * as fs from 'fs';
import * as path from 'path';
import { type Diagnostic } from '@quenty/cli-output-helpers/reporting';
import { OutputHelper } from '@quenty/cli-output-helpers';
import type { SourcemapResolver } from '../../sourcemap/index.js';
import type { AnnotationWorkspace } from './annotation-workspace.js';
import { tryResolveRobloxSourceFile } from './roblox-path-resolver.js';

/** `at ServerScriptService.pkg.Path.spec:45`, line optional */
const AT_FRAME_PATTERN = /^\s+at\s+(\S+?)(?::(\d+))?\s*$/;

/** `ServerScriptService.pkg.Path:1263 function requireModule`, any service root */
const BARE_FRAME_PATTERN =
  /^\s+(\[string "[^"]+"\]|[A-Za-z_][\w-]*(?:\.[^\s:"]+)+):(\d+)(?:\s+function\s+\S+)?\s*$/;

/** `Script '[string "ServerScriptService.pkg.Path"]', Line 23` */
const SCRIPT_FRAME_PATTERN = /Script '(.+?)', Line (\d+)/;

/** `<chunk>:214:` location prefixes inside error messages */
const MESSAGE_LOCATION_PATTERN =
  /(\[string "[^"]+"\]|ServerScriptService\.[^\s:"]+):(\d+):/g;

/** `● TestSuite › nested › test name` */
const FAILURE_HEADER_PATTERN = /^\s*●\s+(.+)$/;

const TITLE_SEPARATOR_PATTERN = / [›>] /;

const enum State {
  IDLE,
  FAILURE_BLOCK,
  STACK_BLOCK,
}

interface Frame {
  instancePath: string;
  line?: number;
}

interface FailureContext {
  title: string;
  messageLines: string[];
  frames: Frame[];
}

interface StackContext {
  errorMessage: string;
  frames: Frame[];
}

interface ResolvedLocation {
  file: string;
  line?: number;
  isPackageUnderTest: boolean;
}

export interface JestLuaParseOptions {
  /** npm name of the package under test, e.g. `@quenty/saveslot`. */
  packageName: string;
  sourcemapResolver?: SourcemapResolver;
  workspace?: AnnotationWorkspace;
  /** Repo root that holds the workspace. Defaults to cwd. */
  repoRoot?: string;
}

function _findTestLineInFile(
  filePath: string,
  title: string
): number | undefined {
  let content: string;
  try {
    content = fs.readFileSync(filePath, 'utf-8');
  } catch {
    return undefined;
  }

  const lines = content.split('\n');
  const names = title.split(TITLE_SEPARATOR_PATTERN).map((name) => name.trim());
  for (const name of names.reverse()) {
    const index = lines.findIndex(
      (line) => line.includes(`("${name}"`) || line.includes(`('${name}'`)
    );
    if (index !== -1) return index + 1;
  }

  return undefined;
}

function _parseFrameLine(rawLine: string): Frame | undefined {
  const match =
    rawLine.match(BARE_FRAME_PATTERN) ?? rawLine.match(AT_FRAME_PATTERN);
  if (!match) return undefined;
  return {
    instancePath: match[1],
    line: match[2] ? parseInt(match[2], 10) : undefined,
  };
}

function _parseMessageLocations(message: string): Frame[] {
  return [...message.matchAll(MESSAGE_LOCATION_PATTERN)].map((match) => ({
    instancePath: match[1],
    line: parseInt(match[2], 10),
  }));
}

function _resolveLocation(
  frames: Frame[],
  options: JestLuaParseOptions
): ResolvedLocation | undefined {
  let fallback: ResolvedLocation | undefined;

  for (const frame of frames) {
    const resolved = tryResolveRobloxSourceFile(frame.instancePath, options);
    if (!resolved) continue;

    const location = { ...resolved, line: frame.line };
    if (resolved.isPackageUnderTest) {
      return location;
    }
    fallback ??= location;
  }

  return fallback;
}

/**
 * Parse Jest-lua verbose output into `Diagnostic[]`.
 *
 * @param raw - Raw test output (may include ANSI codes)
 */
export function parseJestLuaOutput(
  raw: string,
  options: JestLuaParseOptions
): Diagnostic[] {
  const diagnostics: Diagnostic[] = [];
  const clean = OutputHelper.stripAnsi(raw);
  const lines = clean.split('\n');
  const repoRoot = options.repoRoot ?? process.cwd();

  let state: State = State.IDLE;
  let failureCtx: FailureContext | undefined;
  let stackCtx: StackContext | undefined;
  let lastNonEmptyLine = '';

  function _emitFailure(ctx: FailureContext): void {
    const message = ctx.messageLines.join('\n').trim();
    const location = _resolveLocation(
      [...ctx.frames, ..._parseMessageLocations(message)],
      options
    );

    let line = location?.line;
    if (location?.isPackageUnderTest && line === undefined) {
      line = _findTestLineInFile(path.join(repoRoot, location.file), ctx.title);
    }

    diagnostics.push({
      ...(location ? { file: location.file } : {}),
      ...(line !== undefined ? { line } : {}),
      severity: 'error',
      title: ctx.title,
      message: message || 'Test failed',
      source: 'jest-lua',
    });
  }

  function _emitStack(ctx: StackContext): void {
    const location = _resolveLocation(
      [...ctx.frames, ..._parseMessageLocations(ctx.errorMessage)],
      options
    );

    diagnostics.push({
      ...(location ? { file: location.file, line: location.line ?? 1 } : {}),
      severity: 'error',
      title: 'Runtime error',
      message: ctx.errorMessage || 'Unknown runtime error',
      source: 'jest-lua',
    });
  }

  for (let i = 0; i < lines.length; i++) {
    const rawLine = lines[i];

    switch (state) {
      case State.IDLE: {
        const failureMatch = rawLine.match(FAILURE_HEADER_PATTERN);
        if (failureMatch) {
          failureCtx = {
            title: failureMatch[1].trim(),
            messageLines: [],
            frames: [],
          };
          state = State.FAILURE_BLOCK;
          break;
        }

        if (rawLine.trim() === 'Stack Begin') {
          stackCtx = {
            errorMessage: lastNonEmptyLine,
            frames: [],
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

        const frame = _parseFrameLine(rawLine);
        if (frame) {
          failureCtx.frames.push(frame);
          break;
        }

        if (rawLine.trim() === 'Stack Begin') {
          _emitFailure(failureCtx);
          stackCtx = {
            errorMessage:
              failureCtx.messageLines.length > 0
                ? failureCtx.messageLines[
                    failureCtx.messageLines.length - 1
                  ].trim()
                : failureCtx.title,
            frames: [],
          };
          failureCtx = undefined;
          state = State.STACK_BLOCK;
          break;
        }

        const endsBlock =
          FAILURE_HEADER_PATTERN.test(rawLine) ||
          (failureCtx.frames.length > 0 && rawLine.trim() !== '');
        if (endsBlock) {
          _emitFailure(failureCtx);
          failureCtx = undefined;
          state = State.IDLE;
          i--;
          break;
        }

        if (failureCtx.frames.length === 0) {
          failureCtx.messageLines.push(rawLine);
        }
        break;
      }

      case State.STACK_BLOCK: {
        if (!stackCtx) {
          state = State.IDLE;
          break;
        }

        const scriptMatch = rawLine.match(SCRIPT_FRAME_PATTERN);
        if (scriptMatch) {
          stackCtx.frames.push({
            instancePath: scriptMatch[1],
            line: parseInt(scriptMatch[2], 10),
          });
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
