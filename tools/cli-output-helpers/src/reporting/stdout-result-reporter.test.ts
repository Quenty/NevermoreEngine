import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { StdoutResultReporter } from './stdout-result-reporter.js';

describe('StdoutResultReporter', () => {
  let logSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    logSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
  });

  afterEach(() => {
    logSpy.mockRestore();
  });

  it('writes rendered result to stdout on each onResult', () => {
    const reporter = new StdoutResultReporter<{ name: string }>({
      render: (r) => `name=${r.name}`,
    });

    reporter.onResult({ name: 'first' });
    reporter.onResult({ name: 'second' });

    expect(logSpy).toHaveBeenCalledTimes(2);
    expect(logSpy).toHaveBeenNthCalledWith(1, 'name=first');
    expect(logSpy).toHaveBeenNthCalledWith(2, 'name=second');
  });

  it('startAsync and stopAsync are no-ops', async () => {
    const reporter = new StdoutResultReporter<unknown>({ render: () => '' });
    await reporter.startAsync();
    await reporter.stopAsync();
    expect(logSpy).not.toHaveBeenCalled();
  });
});
