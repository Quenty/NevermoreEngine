import { describe, it, expect, vi, afterEach } from 'vitest';
import {
  type Diagnostic,
  formatAnnotation,
  emitAnnotations,
  summarizeDiagnostics,
  formatAnnotationSummaryMarkdown,
} from './annotations.js';

function makeDiagnostic(overrides: Partial<Diagnostic> = {}): Diagnostic {
  return {
    file: 'src/foo.lua',
    line: 10,
    severity: 'error',
    message: 'Something went wrong',
    ...overrides,
  };
}

describe('formatAnnotation', () => {
  it('formats a basic error annotation', () => {
    const result = formatAnnotation(makeDiagnostic());
    expect(result).toBe(
      '::error file=src/foo.lua,line=10::Something went wrong'
    );
  });

  it('formats a warning annotation', () => {
    const result = formatAnnotation(makeDiagnostic({ severity: 'warning' }));
    expect(result).toBe(
      '::warning file=src/foo.lua,line=10::Something went wrong'
    );
  });

  it('includes optional properties', () => {
    const result = formatAnnotation(
      makeDiagnostic({
        endLine: 15,
        column: 3,
        endColumn: 20,
        title: 'TypeError',
      })
    );
    expect(result).toBe(
      '::error file=src/foo.lua,line=10,endLine=15,col=3,endColumn=20,title=TypeError::Something went wrong'
    );
  });

  it('escapes special characters in properties', () => {
    const result = formatAnnotation(
      makeDiagnostic({ title: 'a:b,c' })
    );
    expect(result).toContain('title=a%3Ab%2Cc');
  });

  it('escapes newlines in message', () => {
    const result = formatAnnotation(
      makeDiagnostic({ message: 'line1\nline2\rline3' })
    );
    expect(result).toContain('::line1%0Aline2%0Dline3');
  });

  it('escapes percent signs', () => {
    const result = formatAnnotation(
      makeDiagnostic({ message: '100% done', title: '50% complete' })
    );
    expect(result).toContain('title=50%25 complete');
    expect(result).toContain('::100%25 done');
  });
});

describe('emitAnnotations', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('writes one line per diagnostic to stdout', () => {
    const spy = vi.spyOn(console, 'log').mockImplementation(() => {});
    const diagnostics = [
      makeDiagnostic({ severity: 'error' }),
      makeDiagnostic({ severity: 'warning', file: 'src/bar.lua', line: 5 }),
    ];

    emitAnnotations(diagnostics);

    expect(spy).toHaveBeenCalledTimes(2);
    expect(spy.mock.calls[0][0]).toMatch(/^::error /);
    expect(spy.mock.calls[1][0]).toMatch(/^::warning /);
  });
});

describe('summarizeDiagnostics', () => {
  it('returns zero counts for empty array', () => {
    const summary = summarizeDiagnostics([]);
    expect(summary).toEqual({
      errors: 0,
      warnings: 0,
      notices: 0,
      total: 0,
      fileCount: 0,
    });
  });

  it('counts by severity and unique files', () => {
    const diagnostics = [
      makeDiagnostic({ file: 'a.lua', severity: 'error' }),
      makeDiagnostic({ file: 'a.lua', severity: 'error' }),
      makeDiagnostic({ file: 'b.lua', severity: 'warning' }),
      makeDiagnostic({ file: 'c.lua', severity: 'notice' }),
    ];

    const summary = summarizeDiagnostics(diagnostics);
    expect(summary.errors).toBe(2);
    expect(summary.warnings).toBe(1);
    expect(summary.notices).toBe(1);
    expect(summary.total).toBe(4);
    expect(summary.fileCount).toBe(3);
  });
});

describe('formatAnnotationSummaryMarkdown', () => {
  it('returns "no issues" for empty diagnostics', () => {
    const md = formatAnnotationSummaryMarkdown('luau-lsp', []);
    expect(md).toContain('### luau-lsp');
    expect(md).toContain('No issues found');
  });

  it('renders summary with file details', () => {
    const diagnostics = [
      makeDiagnostic({ file: 'src/a.lua', severity: 'error', line: 10 }),
      makeDiagnostic({ file: 'src/a.lua', severity: 'warning', line: 20 }),
      makeDiagnostic({ file: 'src/b.lua', severity: 'error', line: 5 }),
    ];

    const md = formatAnnotationSummaryMarkdown('Selene', diagnostics);
    expect(md).toContain('### Selene');
    expect(md).toContain('**3 issues**');
    expect(md).toContain('2 files');
    expect(md).toContain('2 errors');
    expect(md).toContain('1 warning');
    expect(md).toContain('src/a.lua');
    expect(md).toContain('src/b.lua');
  });
});
