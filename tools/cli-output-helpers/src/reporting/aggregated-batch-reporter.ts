import { OutputHelper } from '../outputHelper.js';
import { BaseReporter } from './reporter.js';

/**
 * Batch progress for a run that is one execution rather than many.
 *
 * An aggregated batch has no per-package moment to report: every package starts
 * in the same tick, before the task that runs them exists, and finishes in the
 * same tick when it returns. A reporter built around per-package callbacks can
 * only invent structure that is not there — which is what produced one empty
 * group per package, and filed the shared upload under whichever package's
 * async context happened to reach the promise first.
 *
 * So this one says nothing per package. The run is printed once, by whoever
 * holds it, and the summary table recaps at the end.
 */
export class AggregatedBatchReporter extends BaseReporter {
  private _actionVerb: string;
  private _total: number;

  constructor(total: number, options?: { actionVerb?: string }) {
    super();
    this._total = total;
    this._actionVerb = options?.actionVerb ?? 'Processing';
  }

  override async startAsync(): Promise<void> {
    OutputHelper.info(
      `${this._actionVerb} ${this._total} packages in one batch`
    );
  }

  /**
   * Print a run that has already happened: its output, then what reading that
   * output turned up.
   *
   * Taken as rendered lines rather than as a log to render, so the decision of
   * what a line should look like stays in one place and this stays a printer.
   */
  printRun(renderedLines: string[]): void {
    for (const line of renderedLines) {
      console.log(line);
    }
  }
}
