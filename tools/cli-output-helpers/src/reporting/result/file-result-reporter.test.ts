import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

const { mockWriteFileSync } = vi.hoisted(() => ({
  mockWriteFileSync: vi.fn(),
}));

vi.mock('fs', () => ({
  writeFileSync: mockWriteFileSync,
}));

vi.mock('child_process', () => ({
  execSync: vi.fn(),
}));

import { FileResultReporter } from './file-result-reporter.js';

describe('FileResultReporter', () => {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let stderrSpy: any;

  beforeEach(() => {
    mockWriteFileSync.mockReset();
    stderrSpy = vi
      .spyOn(process.stderr, 'write')
      .mockImplementation(() => true);
  });

  afterEach(() => {
    stderrSpy.mockRestore();
  });

  it('writes rendered text to the output path with utf-8 encoding', () => {
    const reporter = new FileResultReporter<{ msg: string }>({
      outputPath: '/tmp/out.txt',
      render: (r) => r.msg,
    });

    reporter.onResult({ msg: 'hello' });

    expect(mockWriteFileSync).toHaveBeenCalledWith(
      '/tmp/out.txt',
      'hello',
      'utf-8'
    );
  });

  it('writes a Buffer when binary callback returns one', () => {
    const buf = Buffer.from([1, 2, 3]);
    const reporter = new FileResultReporter<{ b: Buffer }>({
      outputPath: '/tmp/out.bin',
      render: () => 'fallback',
      binary: (r) => r.b,
    });

    reporter.onResult({ b: buf });

    expect(mockWriteFileSync).toHaveBeenCalledWith('/tmp/out.bin', buf);
  });

  it('reports "binary output" status for binary writes', () => {
    const reporter = new FileResultReporter<{ b: Buffer }>({
      outputPath: '/tmp/out.bin',
      render: () => '',
      binary: (r) => r.b,
    });

    reporter.onResult({ b: Buffer.from([0]) });

    expect(stderrSpy).toHaveBeenCalledWith(
      'Wrote binary output to /tmp/out.bin\n'
    );
  });

  it('falls back to text render when binary returns undefined', () => {
    const reporter = new FileResultReporter<{ b?: Buffer }>({
      outputPath: '/tmp/out.txt',
      render: () => 'text',
      binary: () => undefined,
    });

    reporter.onResult({});

    expect(mockWriteFileSync).toHaveBeenCalledWith(
      '/tmp/out.txt',
      'text',
      'utf-8'
    );
  });

  it('emits a status line to stderr by default', () => {
    const reporter = new FileResultReporter<unknown>({
      outputPath: '/tmp/out.txt',
      render: () => '',
    });

    reporter.onResult(null);

    expect(stderrSpy).toHaveBeenCalledWith('Wrote output to /tmp/out.txt\n');
  });

  it('suppresses status when reportPath is false', () => {
    const reporter = new FileResultReporter<unknown>({
      outputPath: '/tmp/out.txt',
      render: () => '',
      reportPath: false,
    });

    reporter.onResult(null);

    expect(stderrSpy).not.toHaveBeenCalled();
  });
});
