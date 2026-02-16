import { OutputHelper } from '../outputHelper.js';
import { formatDurationMs } from '../cli-utils.js';
import { type PackageResult, BaseReporter } from './reporter.js';
import { type IStateTracker } from './state/state-tracker.js';

export interface SpinnerReporterOptions {
  showLogs: boolean;
  /** Verb used in the header, e.g. "Testing", "Deploying". Default: "Processing" */
  actionVerb?: string;
}

const SPINNER_FRAMES = ['◐', '◓', '◑', '◒'];

/**
 * TTY spinner rendering for batch job progress.
 * Reads all state from IStateTracker; re-renders on a timer interval.
 */
export class SpinnerReporter extends BaseReporter {
  private _state: IStateTracker;
  private _options: SpinnerReporterOptions;
  private _renderedLineCount: number = 0;
  private _renderInterval?: ReturnType<typeof setInterval>;
  private _spinnerFrame: number = 0;

  constructor(state: IStateTracker, options: SpinnerReporterOptions) {
    super();
    this._state = state;
    this._options = options;
  }

  override async startAsync(): Promise<void> {
    const count = this._state.total;
    const verb = this._options.actionVerb ?? 'Processing';
    console.log(
      OutputHelper.formatInfo(
        `${verb} ${count} ${count === 1 ? 'package' : 'packages'}\n`
      )
    );
    process.stdout.write('\x1b[?25l');
    this._renderedLineCount = 0;
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
    process.stdout.write('\x1b[?25h');
    console.log('');

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
    const status = result.success ? 'Passed' : 'FAILED';
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

      switch (state.status) {
        case 'pending': {
          const icon = OutputHelper.formatDim('○');
          const statusText = OutputHelper.formatDim('Queued');
          line = `  ${icon} ${OutputHelper.formatDim(
            state.name.padEnd(30)
          )} ${statusText}`;
          break;
        }
        case 'building': {
          const icon = OutputHelper.formatInfo(spinner);
          const statusText = OutputHelper.formatInfo('⚙ Building');
          line = `  ${icon} ${state.name.padEnd(30)} ${statusText.padEnd(
            22
          )} ${OutputHelper.formatDim(time)}`;
          break;
        }
        case 'uploading': {
          const icon = OutputHelper.formatInfo(spinner);
          const statusText = OutputHelper.formatInfo('▲ Uploading');
          line = `  ${icon} ${state.name.padEnd(30)} ${statusText.padEnd(
            22
          )} ${OutputHelper.formatDim(time)}`;
          break;
        }
        case 'scheduling': {
          const icon = OutputHelper.formatInfo(spinner);
          const statusText = OutputHelper.formatInfo('◇ Scheduling');
          line = `  ${icon} ${state.name.padEnd(30)} ${statusText.padEnd(
            22
          )} ${OutputHelper.formatDim(time)}`;
          break;
        }
        case 'executing': {
          const icon = OutputHelper.formatInfo(spinner);
          const statusText = OutputHelper.formatInfo('▶ Executing');
          line = `  ${icon} ${state.name.padEnd(30)} ${statusText.padEnd(
            22
          )} ${OutputHelper.formatDim(time)}`;
          break;
        }
        case 'passed': {
          const icon = OutputHelper.formatSuccess('✓');
          const statusText = OutputHelper.formatSuccess('Passed');
          line = `  ${icon} ${state.name.padEnd(30)} ${statusText.padEnd(
            20
          )} ${OutputHelper.formatDim(time)}`;
          break;
        }
        case 'failed': {
          const icon = OutputHelper.formatError('✗');
          const statusText = OutputHelper.formatError('FAILED');
          line = `  ${icon} ${state.name.padEnd(30)} ${statusText.padEnd(
            20
          )} ${OutputHelper.formatDim(time)}`;
          break;
        }
      }

      lines.push(line);
    }

    lines.push('');
    lines.push(
      OutputHelper.formatDim(
        `${this._state.completed}/${this._state.total} complete`
      )
    );

    let frame = '';
    if (this._renderedLineCount > 0) {
      frame += `\x1b[${this._renderedLineCount}A\x1b[0J`;
    }
    frame += lines.join('\n') + '\n';
    process.stdout.write(frame);
    this._renderedLineCount = lines.length;
  }
}
