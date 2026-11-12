import { StudioBridgeError } from './studio-bridge-error.js';

export const UNEXPECTED_ERROR_CODE = 'UNEXPECTED_ERROR';
const VERBOSE_HINT = 'Run with --verbose for details.';

export interface ErrorReport {
  code: string;
  error: string;
  fix?: string;
  cause?: string;
}

export function describeError(err: unknown, verbose: boolean): ErrorReport {
  if (err instanceof StudioBridgeError) {
    return {
      code: err.code,
      error: err.message,
      ...(err.fix ? { fix: err.fix } : {}),
      ...(verbose && err.cause !== undefined
        ? { cause: formatCause(err.cause) }
        : {}),
    };
  }

  const summary = `Unexpected error: ${withoutEndPunctuation(
    firstLine(err instanceof Error ? err.message : String(err))
  )}.`;
  return verbose
    ? { code: UNEXPECTED_ERROR_CODE, error: summary, cause: formatCause(err) }
    : { code: UNEXPECTED_ERROR_CODE, error: `${summary} ${VERBOSE_HINT}` };
}

export function formatCause(cause: unknown): string {
  const lines: string[] = [];
  const seen = new Set<unknown>();
  let current = cause;
  while (current !== undefined && !seen.has(current)) {
    seen.add(current);
    lines.push(
      current instanceof Error
        ? current.stack ?? current.message
        : String(current)
    );
    current = current instanceof Error ? current.cause : undefined;
  }
  return lines.join('\nCaused by: ');
}

function firstLine(text: string): string {
  return text.trim().split('\n')[0].trim() || 'no message';
}

export function withoutEndPunctuation(text: string): string {
  return text.replace(/[.:;!]+$/, '');
}
