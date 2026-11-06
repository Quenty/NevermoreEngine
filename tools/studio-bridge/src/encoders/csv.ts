/**
 * CSV encoding (RFC 4180 quoting): a header line, then one line per row,
 * with `\n` line endings and a trailing newline.
 */

export type CsvValue = string | number | boolean;

/**
 * Encodes `rows` under the `columns` header. Each row holds one value per
 * column, in the same order.
 */
export function formatCsv(
  columns: readonly string[],
  rows: Iterable<readonly CsvValue[]>
): string {
  const lines = [columns.map(toCsvField).join(',')];
  for (const row of rows) {
    lines.push(row.map(toCsvField).join(','));
  }
  return lines.join('\n') + '\n';
}

/** Quotes a field when it holds a comma, quote or line break. */
export function toCsvField(value: CsvValue): string {
  const text = String(value);
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}
