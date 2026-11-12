import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { DirectoryResultReporter } from './directory-result-reporter.js';

describe('DirectoryResultReporter', () => {
  let outputDir: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let stderrSpy: any;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let logSpy: any;

  beforeEach(() => {
    outputDir = path.join(
      fs.mkdtempSync(path.join(os.tmpdir(), 'directory-reporter-')),
      'out'
    );
    stderrSpy = vi
      .spyOn(process.stderr, 'write')
      .mockImplementation(() => true);
    logSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
  });

  afterEach(() => {
    stderrSpy.mockRestore();
    logSpy.mockRestore();
    fs.rmSync(path.dirname(outputDir), { recursive: true, force: true });
  });

  it('creates the directory and writes every file into it', () => {
    const reporter = new DirectoryResultReporter<{ count: number }>({
      outputDir,
      render: (r) => `${r.count} files`,
      files: () => [
        { relativePath: 'a.txt', data: 'text' },
        { relativePath: 'b.bin', data: Buffer.from([1, 2, 3]) },
      ],
    });

    reporter.onResult({ count: 2 });

    expect(fs.readFileSync(path.join(outputDir, 'a.txt'), 'utf-8')).toBe(
      'text'
    );
    expect([...fs.readFileSync(path.join(outputDir, 'b.bin'))]).toEqual([
      1, 2, 3,
    ]);
    expect(stderrSpy).toHaveBeenCalledWith(`Wrote 2 files to ${outputDir}\n`);
    expect(logSpy).toHaveBeenCalledWith('2 files');
  });
});
