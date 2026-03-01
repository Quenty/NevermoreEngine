/**
 * JSON output formatter. Pretty-prints when connected to a TTY,
 * emits compact JSON when piped.
 */

export interface JsonOutputOptions {
  pretty?: boolean;
}

export function formatJson(data: unknown, options?: JsonOutputOptions): string {
  const pretty = options?.pretty ?? (process.stdout.isTTY ? true : false);
  if (pretty) {
    return JSON.stringify(data, null, 2);
  }
  return JSON.stringify(data);
}
