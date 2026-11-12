import { invalidInput } from '../../messages/studio-bridge-error.js';
const UNIT_SECONDS: Record<string, number> = {
  ms: 0.001,
  s: 1,
  m: 60,
  h: 3600,
  d: 86400,
};

export function tryParseDurationSeconds(value: string): number | undefined {
  const match = /^(\d+(?:\.\d+)?)(ms|s|m|h|d)$/.exec(value.trim());
  if (!match) {
    return undefined;
  }
  return Number(match[1]) * UNIT_SECONDS[match[2]];
}

export function parseDurationSeconds(
  value: string | number,
  flag: string
): number {
  const seconds =
    typeof value === 'number'
      ? value
      : /^\d+(?:\.\d+)?$/.test(value.trim())
      ? Number(value)
      : tryParseDurationSeconds(value);

  if (seconds === undefined || !Number.isFinite(seconds) || seconds < 0) {
    throw invalidInput(
      `Can't read ${flag} '${value}'.`,
      'Give a duration like 800ms, 0.8s or 2s. A bare number is seconds.'
    );
  }
  return seconds;
}
