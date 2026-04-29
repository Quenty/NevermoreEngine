/**
 * Fans out single-result reporting to multiple ResultReporter instances.
 * Mirrors CompositeReporter (for batch lifecycle) but for single-result
 * output.
 */

import type { ResultReporter } from './result-reporter.js';

export class CompositeResultReporter<T = unknown> implements ResultReporter<T> {
  private _reporters: ResultReporter<T>[];

  constructor(reporters: ResultReporter<T>[]) {
    this._reporters = reporters;
  }

  async startAsync(): Promise<void> {
    const results = await Promise.allSettled(
      this._reporters.map((r) => r.startAsync())
    );
    this._throwFirstRejection(results, 'startAsync');
  }

  onResult(result: T): void {
    const errors: unknown[] = [];
    for (const r of this._reporters) {
      try {
        r.onResult(result);
      } catch (err) {
        errors.push(err);
      }
    }
    if (errors.length > 0) {
      throw errors[0];
    }
  }

  async stopAsync(): Promise<void> {
    const results = await Promise.allSettled(
      this._reporters.map((r) => r.stopAsync())
    );
    this._throwFirstRejection(results, 'stopAsync');
  }

  private _throwFirstRejection(
    results: PromiseSettledResult<unknown>[],
    phase: string
  ): void {
    const firstRejected = results.find(
      (r): r is PromiseRejectedResult => r.status === 'rejected'
    );
    if (firstRejected) {
      const reason = firstRejected.reason;
      throw reason instanceof Error
        ? reason
        : new Error(`Reporter ${phase} failed: ${String(reason)}`);
    }
  }
}
