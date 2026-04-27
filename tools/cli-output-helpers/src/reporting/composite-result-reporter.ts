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
    for (const r of this._reporters) {
      await r.startAsync();
    }
  }

  onResult(result: T): void {
    for (const r of this._reporters) {
      r.onResult(result);
    }
  }

  async stopAsync(): Promise<void> {
    for (const r of this._reporters) {
      await r.stopAsync();
    }
  }
}
