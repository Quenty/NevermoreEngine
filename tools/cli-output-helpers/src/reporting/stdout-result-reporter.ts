/**
 * Writes a rendered result to stdout. One-shot — calls render(result) and
 * console.log(...) on each onResult.
 */

import { BaseResultReporter } from './result-reporter.js';

export interface StdoutResultReporterOptions<T> {
  render: (result: T) => string;
}

export class StdoutResultReporter<T = unknown> extends BaseResultReporter<T> {
  private _render: (result: T) => string;

  constructor(options: StdoutResultReporterOptions<T>) {
    super();
    this._render = options.render;
  }

  override onResult(result: T): void {
    console.log(this._render(result));
  }
}
