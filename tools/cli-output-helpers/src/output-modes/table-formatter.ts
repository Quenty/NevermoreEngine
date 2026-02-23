/**
 * Generic table formatter for CLI output. Computes column widths from data,
 * handles ANSI color codes in values, and supports left/right alignment.
 */

export interface TableColumn<T> {
  header: string;
  value: (row: T) => string;
  minWidth?: number;
  align?: 'left' | 'right';
  format?: (value: string, row: T) => string;
}

export interface TableOptions {
  showHeaders?: boolean;
  showSeparator?: boolean;
  indent?: string;
}

/** Strip ANSI escape codes so width calculations reflect visible characters. */
function stripAnsi(text: string): string {
  return text.replace(/\x1b\[[0-9;]*m/g, '');
}

function padCell(text: string, width: number, align: 'left' | 'right'): string {
  const visibleLength = stripAnsi(text).length;
  const padding = Math.max(0, width - visibleLength);
  if (align === 'right') {
    return ' '.repeat(padding) + text;
  }
  return text + ' '.repeat(padding);
}

export function formatTable<T>(
  rows: T[],
  columns: TableColumn<T>[],
  options?: TableOptions
): string {
  if (rows.length === 0) {
    return '';
  }

  const showHeaders = options?.showHeaders ?? true;
  const showSeparator = options?.showSeparator ?? true;
  const indent = options?.indent ?? '';

  // Pre-compute raw string values for every cell
  const cellValues: string[][] = rows.map((row) =>
    columns.map((col) => col.value(row))
  );

  // Compute column widths
  const widths = columns.map((col, colIndex) => {
    const headerWidth = col.header.length;
    const minWidth = col.minWidth ?? 0;
    const maxDataWidth = cellValues.reduce(
      (max, rowValues) => Math.max(max, stripAnsi(rowValues[colIndex]).length),
      0
    );
    return Math.max(headerWidth, minWidth, maxDataWidth);
  });

  const lines: string[] = [];

  // Header row
  if (showHeaders) {
    const headerCells = columns.map((col, i) =>
      padCell(col.header, widths[i], col.align ?? 'left')
    );
    lines.push(headerCells.join('  '));
  }

  // Separator row
  if (showSeparator && showHeaders) {
    const separatorCells = widths.map((w) => '-'.repeat(w));
    lines.push(separatorCells.join('  '));
  }

  // Data rows
  for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    const row = rows[rowIndex];
    const cells = columns.map((col, colIndex) => {
      let value = cellValues[rowIndex][colIndex];
      if (col.format) {
        value = col.format(value, row);
      }
      return padCell(value, widths[colIndex], col.align ?? 'left');
    });
    lines.push(cells.join('  '));
  }

  if (indent) {
    return lines.map((line) => indent + line).join('\n');
  }

  return lines.join('\n');
}
