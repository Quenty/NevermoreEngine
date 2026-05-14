import { describe, it, expect } from 'vitest';
import { buildResultReporter } from './build-result-reporter.js';
import { StdoutResultReporter } from './stdout-result-reporter.js';
import { FileResultReporter } from './file-result-reporter.js';
import { WatchResultReporter } from './watch-result-reporter.js';

describe('buildResultReporter', () => {
  const render = (r: unknown) => String(r);

  it('returns a StdoutResultReporter by default', () => {
    const reporter = buildResultReporter({ render });
    expect(reporter).toBeInstanceOf(StdoutResultReporter);
  });

  it('returns a FileResultReporter when outputPath is set', () => {
    const reporter = buildResultReporter({
      outputPath: '/tmp/out.txt',
      render,
    });
    expect(reporter).toBeInstanceOf(FileResultReporter);
  });

  it('returns a WatchResultReporter when watch is true and no outputPath', () => {
    const reporter = buildResultReporter({ watch: true, render });
    expect(reporter).toBeInstanceOf(WatchResultReporter);
  });

  it('outputPath wins over watch', () => {
    const reporter = buildResultReporter({
      outputPath: '/tmp/out.txt',
      watch: true,
      render,
    });
    expect(reporter).toBeInstanceOf(FileResultReporter);
  });

  it('treats empty-string outputPath as a file destination', () => {
    // Empty string is a valid (if degenerate) path — selection is by
    // presence of the field, not truthiness.
    const reporter = buildResultReporter({ outputPath: '', render });
    expect(reporter).toBeInstanceOf(FileResultReporter);
  });

  it('returns Stdout when watch is false and no outputPath', () => {
    const reporter = buildResultReporter({ watch: false, render });
    expect(reporter).toBeInstanceOf(StdoutResultReporter);
  });
});
