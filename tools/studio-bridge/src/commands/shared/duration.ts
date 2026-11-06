/**
 * Duration strings shared by the commands that take one (`console logs
 * --since`, `--duration` on recording commands).
 */

const UNIT_SECONDS: Record<string, number> = {
  ms: 0.001,
  s: 1,
  m: 60,
  h: 3600,
  d: 86400,
};

/**
 * Seconds in a duration with a unit (`800ms`, `0.8s`, `5m`, `2h`, `1d`), or
 * undefined when `value` is not one.
 */
export function tryParseDurationSeconds(value: string): number | undefined {
  const match = /^(\d+(?:\.\d+)?)(ms|s|m|h|d)$/.exec(value.trim());
  if (!match) {
    return undefined;
  }
  return Number(match[1]) * UNIT_SECONDS[match[2]];
}

/**
 * Seconds in a duration with a unit, or a bare number of seconds. Throws,
 * naming `flag`, when `value` is neither.
 */
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
    throw new Error(
      `Can't read ${flag} '${value}'. Use a duration like 800ms, 0.8s or 2s (a bare number is seconds).`
    );
  }
  return seconds;
}
