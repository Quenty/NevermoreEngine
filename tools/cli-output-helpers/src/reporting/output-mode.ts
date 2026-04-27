/**
 * Resolves which output mode a command should use based on flags,
 * environment variables, and TTY detection.
 */

export type OutputMode = 'table' | 'json' | 'text';

export function resolveOutputMode(options: {
  json?: boolean;
  isTTY?: boolean;
  envOverride?: string;
}): OutputMode {
  if (options.json === true) {
    return 'json';
  }
  if (options.envOverride === 'json') {
    return 'json';
  }
  if (options.envOverride === 'text') {
    return 'text';
  }
  if (options.isTTY === false) {
    return 'text';
  }
  return 'table';
}
