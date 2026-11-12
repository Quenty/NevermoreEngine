export type CsvValue = string | number | boolean;

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

export function toCsvField(value: CsvValue): string {
  const text = String(value);
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}
