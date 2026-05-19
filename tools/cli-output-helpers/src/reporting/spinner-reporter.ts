import { OutputHelper } from '../outputHelper.js';
import { formatDurationMs } from '../cli-utils.js';
import { type PackageResult, BaseReporter } from './reporter.js';
import { type IStateTracker } from './state/state-tracker.js';
import {
  formatProgressInline,
  formatProgressResult,
  isEmptyTestRun,
} from './progress-format.js';

export interface SpinnerReporterOptions {
  showLogs: boolean;
  /** Verb used in the header, e.g. "Testing", "Deploying". Default: "Processing" */
  actionVerb?: string;
  /** Extra context appended to the header line, e.g. "to target 'integration'". */
  actionContext?: string;
  /** Label for successful results, e.g. "Deployed". Default: "Passed" */
  successLabel?: string;
  /** Label for failed results, e.g. "DEPLOY FAILED". Default: "FAILED" */
  failureLabel?: string;
}

const SPINNER_FRAMES = ['◐', '◓', '◑', '◒'];

/** Emoji + label for each active phase in the spinner. */
const PHASE_LABELS: Record<string, string> = {
  waiting: '◇ Waiting',
  building: '⚙ Building',
  combining: '🔗 Combining',
  uploading: '▲ Uploading',
  scheduling: '◇ Scheduling',
  launching: '🚀 Launching',
  connecting: '🔌 Connecting',
  executing: '▶ Executing',
};

/**
 * TTY spinner rendering for batch job progress.
 * Reads all state from IStateTracker; re-renders on a timer interval.
 *
 * Stdout/stderr writes between startAsync() and stopAsync() are *captured*,
 * not passed through. The spinner repaints by rewinding the cursor with
 * `\x1b[NA\x1b[0J`, so any write that landed inside the spinner's render
 * region would be erased on the next 80ms tick. Callers should not have to
 * think about that — we buffer writes and flush them in stopAsync(), so
 * `console.log` / `OutputHelper.info` / etc. during a run still surface,
 * just after the spinner has finished.
 */
export class SpinnerReporter extends BaseReporter {
  private _state: IStateTracker;
  private _options: SpinnerReporterOptions;
  private _renderedLineCount: number = 0;
  private _renderInterval?: ReturnType<typeof setInterval>;
  private _spinnerFrame: number = 0;
  private _capturedOutput: string = '';
  private _originalStdoutWrite: typeof process.stdout.write | undefined;
  private _originalStderrWrite: typeof process.stderr.write | undefined;
  private _isRendering = false;

  constructor(state: IStateTracker, options: SpinnerReporterOptions) {
    super();
    this._state = state;
    this._options = options;
  }

  override async startAsync(): Promise<void> {
    const count = this._state.total;
    const verb = this._options.actionVerb ?? 'Processing';
    const noun = count === 1 ? 'package' : 'packages';
    const context = this._options.actionContext;
    const header = context
      ? `${verb} ${count} ${noun} ${context}`
      : `${verb} ${count} ${noun}`;
    console.log(OutputHelper.formatInfo(`${header}\n`));
    process.stdout.write('\x1b[?25l');
    this._renderedLineCount = 0;

    // Intercept stdout/stderr. External writes during the spinner are
    // captured into a buffer instead of going to the terminal, otherwise the
    // next 80ms render tick would clobber them via the cursor-rewind. The
    // buffer is flushed in stopAsync() so callers still see their output —
    // just after the spinner finishes. Writes made *by* the spinner itself
    // (_isRendering=true) pass through normally.
    this._originalStdoutWrite = process.stdout.write.bind(process.stdout);
    this._originalStderrWrite = process.stderr.write.bind(process.stderr);
    const self = this;
    const intercept =
      (originalWrite: typeof process.stdout.write, stream: NodeJS.WriteStream) =>
        function (chunk: any, ...args: any[]) {
          if (self._isRendering) {
            return originalWrite.call(stream, chunk, ...args);
          }
          const str = typeof chunk === 'string' ? chunk : chunk.toString();
          self._capturedOutput += str;
          // Invoke the optional Node-style completion callback if present.
          const cb = args.find((a) => typeof a === 'function');
          if (cb) cb();
          return true;
        };
    process.stdout.write = intercept(
      this._originalStdoutWrite,
      process.stdout
    ) as any;
    process.stderr.write = intercept(
      this._originalStderrWrite,
      process.stderr
    ) as any;

    this._render();
    this._renderInterval = setInterval(() => {
      this._spinnerFrame = (this._spinnerFrame + 1) % SPINNER_FRAMES.length;
      this._render();
    }, 80);
  }

  override async stopAsync(): Promise<void> {
    if (this._renderInterval) {
      clearInterval(this._renderInterval);
      this._renderInterval = undefined;
    }
    this._render();

    // Restore original stdout.write / stderr.write
    if (this._originalStdoutWrite) {
      process.stdout.write = this._originalStdoutWrite;
      this._originalStdoutWrite = undefined;
    }
    if (this._originalStderrWrite) {
      process.stderr.write = this._originalStderrWrite;
      this._originalStderrWrite = undefined;
    }

    process.stdout.write('\x1b[?25h');
    console.log('');

    // Flush anything captured during the run. Goes out *after* the final
    // spinner frame so callers see their late prints below the progress.
    if (this._capturedOutput.length > 0) {
      process.stdout.write(this._capturedOutput);
      this._capturedOutput = '';
    }

    if (this._options.showLogs) {
      this._printAllLogs();
    } else {
      this._printFailureLogs();
    }
  }

  private _printFailureLogs(): void {
    const failures = this._state.getFailures();
    if (failures.length === 0) return;

    console.log(OutputHelper.formatError(`\n${failures.length} failed:\n`));

    for (const result of failures) {
      this._printResultLogs(result);
    }
  }

  private _printAllLogs(): void {
    for (const result of this._state.getResults()) {
      this._printResultLogs(result);
    }
  }

  private _printResultLogs(result: PackageResult): void {
    const icon = result.success
      ? OutputHelper.formatSuccess('✓')
      : OutputHelper.formatError('✗');
    const status = result.success
      ? this._options.successLabel ?? 'Passed'
      : this._options.failureLabel ?? 'FAILED';
    const formatted = result.success
      ? OutputHelper.formatSuccess(status)
      : OutputHelper.formatError(status);

    console.log(
      `${icon} ${OutputHelper.formatDim('──')} ${
        result.packageName
      } ${OutputHelper.formatDim('──')} ${formatted}`
    );

    if (result.logs) {
      console.log(result.logs);
    } else {
      console.log(OutputHelper.formatDim('  (no output)'));
    }
    if (result.error) {
      console.log(`  ${OutputHelper.formatError(result.error)}`);
    }
    console.log('');
  }

  private _render(): void {
    const lines: string[] = [];
    const spinner = SPINNER_FRAMES[this._spinnerFrame];

    for (const state of this._state.getAllPackages()) {
      const elapsed = state.startMs
        ? state.durationMs ?? Date.now() - state.startMs
        : 0;
      const time = elapsed > 0 ? formatDurationMs(elapsed) : '';

      let line: string;

      const phaseLabel = PHASE_LABELS[state.status];

      if (state.status === 'pending') {
        const icon = OutputHelper.formatDim('○');
        const statusText = OutputHelper.formatDim('Queued');
        line = `  ${icon} ${OutputHelper.formatDim(
          state.name.padEnd(30)
        )} ${statusText}`;
      } else if (phaseLabel) {
        const icon = OutputHelper.formatInfo(spinner);
        const progressText = formatProgressInline(state.progress);
        const plain = progressText
          ? `${phaseLabel} ${progressText}`
          : phaseLabel;
        const statusText = OutputHelper.formatInfo(plain.padEnd(22));
        line = `  ${icon} ${state.name.padEnd(
          30
        )} ${statusText} ${OutputHelper.formatDim(time)}`;
      } else if (state.status === 'passed') {
        const icon = OutputHelper.formatSuccess('✓');
        const progressText = formatProgressResult(
          state.result?.progressSummary
        );
        const label = this._options.successLabel ?? 'Passed';
        const empty = isEmptyTestRun(state.result?.progressSummary);
        let plain = progressText ? `${label} ${progressText}` : label;
        if (empty) plain += ' ⚠';
        const statusText = empty
          ? OutputHelper.formatWarning(plain.padEnd(22))
          : OutputHelper.formatSuccess(plain.padEnd(22));
        line = `  ${icon} ${state.name.padEnd(
          30
        )} ${statusText} ${OutputHelper.formatDim(time)}`;
      } else {
        const icon = OutputHelper.formatError('✗');
        const failedPhase = state.result?.failedPhase;
        const plain = failedPhase
          ? `${this._options.failureLabel ?? 'FAILED'} at ${failedPhase}`
          : this._options.failureLabel ?? 'FAILED';
        const statusText = OutputHelper.formatError(plain.padEnd(22));
        line = `  ${icon} ${state.name.padEnd(
          30
        )} ${statusText} ${OutputHelper.formatDim(time)}`;
      }

      lines.push(line);
    }

    lines.push('');
    lines.push(
      OutputHelper.formatDim(
        `${this._state.completed}/${this._state.total} complete`
      )
    );

    this._isRendering = true;
    let frame = '';
    if (this._renderedLineCount > 0) {
      frame += `\x1b[${this._renderedLineCount}A\x1b[0J`;
    }
    frame += lines.join('\n') + '\n';
    process.stdout.write(frame);
    this._renderedLineCount = lines.length;
    this._isRendering = false;
  }
}
