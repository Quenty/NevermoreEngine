import { describe, it, expect } from 'vitest';
import { formatTable, type TableColumn } from './table-formatter.js';

interface TestRow {
  name: string;
  value: number;
}

const basicColumns: TableColumn<TestRow>[] = [
  { header: 'Name', value: (r) => r.name },
  { header: 'Value', value: (r) => String(r.value) },
];

describe('formatTable', () => {
  it('renders a basic table with 2 columns and 2 rows', () => {
    const rows: TestRow[] = [
      { name: 'alpha', value: 10 },
      { name: 'beta', value: 200 },
    ];

    const result = formatTable(rows, basicColumns);
    const lines = result.split('\n');

    expect(lines).toHaveLength(4); // header + separator + 2 data rows
    expect(lines[0]).toContain('Name');
    expect(lines[0]).toContain('Value');
    expect(lines[1]).toMatch(/^-+\s+-+$/);
    expect(lines[2]).toContain('alpha');
    expect(lines[3]).toContain('beta');
  });

  it('returns empty string for empty rows', () => {
    expect(formatTable([], basicColumns)).toBe('');
  });

  it('handles ANSI color codes in values without breaking alignment', () => {
    const rows = [
      { name: '\x1b[32mgreen\x1b[0m', value: 1 },
      { name: 'plain', value: 2 },
    ];

    const result = formatTable(rows, basicColumns);
    const lines = result.split('\n');

    // Both data rows should produce the same visible width for the Name column.
    // The ANSI-colored row should have padding based on visible "green" (5 chars),
    // not the full escape-code string length.
    const stripAnsi = (s: string) => s.replace(/\x1b\[[0-9;]*m/g, '');
    const dataLine0 = stripAnsi(lines[2]);
    const dataLine1 = stripAnsi(lines[3]);

    // Split by double-space to find column boundary
    const col0Width0 = dataLine0.indexOf('1');
    const col0Width1 = dataLine1.indexOf('2');
    expect(col0Width0).toBe(col0Width1);
  });

  it('right-aligns by padding on the left', () => {
    const columns: TableColumn<TestRow>[] = [
      { header: 'Name', value: (r) => r.name },
      { header: 'Value', value: (r) => String(r.value), align: 'right' },
    ];
    const rows: TestRow[] = [
      { name: 'a', value: 1 },
      { name: 'b', value: 200 },
    ];

    const result = formatTable(rows, columns);
    const lines = result.split('\n');

    // The header "Value" is 5 chars wide; data "1" should be padded to "    1" or similar
    // In the first data row, the value column should end with '1' preceded by spaces
    const dataLine = lines[2];
    // Right-aligned: the value "1" should appear at the right edge of the value column
    expect(dataLine).toMatch(/\s+1$/);
  });

  it('applies custom indent to every line', () => {
    const rows: TestRow[] = [{ name: 'x', value: 1 }];
    const result = formatTable(rows, basicColumns, { indent: '    ' });
    const lines = result.split('\n');

    for (const line of lines) {
      expect(line.startsWith('    ')).toBe(true);
    }
  });

  it('respects minWidth', () => {
    const columns: TableColumn<TestRow>[] = [
      { header: 'N', value: (r) => r.name, minWidth: 20 },
      { header: 'V', value: (r) => String(r.value) },
    ];
    const rows: TestRow[] = [{ name: 'a', value: 1 }];

    const result = formatTable(rows, columns);
    const lines = result.split('\n');

    // The separator dashes for the first column should be at least 20 chars
    const separatorParts = lines[1].split('  ');
    expect(separatorParts[0].length).toBeGreaterThanOrEqual(20);
  });

  it('applies format function to cell values', () => {
    const columns: TableColumn<TestRow>[] = [
      { header: 'Name', value: (r) => r.name, format: (v) => `[${v}]` },
      { header: 'Value', value: (r) => String(r.value) },
    ];
    const rows: TestRow[] = [{ name: 'test', value: 42 }];

    const result = formatTable(rows, columns);
    expect(result).toContain('[test]');
  });
});
