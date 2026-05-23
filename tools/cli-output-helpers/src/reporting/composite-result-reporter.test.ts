import { describe, it, expect } from 'vitest';
import { CompositeResultReporter } from './composite-result-reporter.js';
import { BaseResultReporter, type ResultReporter } from './result-reporter.js';

class RecordingReporter<T> extends BaseResultReporter<T> {
  startCount = 0;
  stopCount = 0;
  results: T[] = [];

  override async startAsync(): Promise<void> {
    this.startCount++;
  }

  override onResult(result: T): void {
    this.results.push(result);
  }

  override async stopAsync(): Promise<void> {
    this.stopCount++;
  }
}

describe('CompositeResultReporter', () => {
  it('fans out lifecycle hooks to every child reporter', async () => {
    const a = new RecordingReporter<number>();
    const b = new RecordingReporter<number>();
    const composite = new CompositeResultReporter<number>([a, b]);

    await composite.startAsync();
    composite.onResult(1);
    composite.onResult(2);
    await composite.stopAsync();

    expect(a.startCount).toBe(1);
    expect(b.startCount).toBe(1);
    expect(a.results).toEqual([1, 2]);
    expect(b.results).toEqual([1, 2]);
    expect(a.stopCount).toBe(1);
    expect(b.stopCount).toBe(1);
  });

  it('preserves call order across reporters', async () => {
    const order: string[] = [];

    const make = (name: string): ResultReporter<unknown> => ({
      async startAsync() {
        order.push(`${name}:start`);
      },
      onResult() {
        order.push(`${name}:result`);
      },
      async stopAsync() {
        order.push(`${name}:stop`);
      },
    });

    const composite = new CompositeResultReporter([make('a'), make('b')]);
    await composite.startAsync();
    composite.onResult(null);
    await composite.stopAsync();

    expect(order).toEqual([
      'a:start',
      'b:start',
      'a:result',
      'b:result',
      'a:stop',
      'b:stop',
    ]);
  });
});
