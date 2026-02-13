import { OutputHelper } from '@quenty/cli-output-helpers';
import { TestablePackage } from './changed-tests-utils.js';
import { BatchTestResult, type TestPhase } from './batch-test-runner.js';
import { formatDurationMs } from '../nevermore-cli-utils.js';

type PackageStatus = 'queued' | 'building' | 'uploading' | 'scheduling' | 'executing' | 'passed' | 'failed';

interface PackageState {
  name: string;
  status: PackageStatus;
  startMs?: number;
  durationMs?: number;
  bufferedOutput?: string[];
}

export interface BatchTestReporterOptions {
  verbose: boolean;
  showLogs: boolean;
}

const SPINNER_FRAMES = ['◐', '◓', '◑', '◒'];

export class BatchTestReporter {
  private _options: BatchTestReporterOptions;
  private _mode: 'spinner' | 'grouped';
  private _packages: Map<string, PackageState>;
  private _total: number;
  private _isCI: boolean;

  // Spinner state
  private _renderedLineCount: number = 0;
  private _renderInterval?: ReturnType<typeof setInterval>;
  private _spinnerFrame: number = 0;
  private _completed: number = 0;

  // Collected results for post-spinner output
  private _failures: BatchTestResult[] = [];
  private _allResults: BatchTestResult[] = [];

  constructor(
    packages: TestablePackage[],
    options: BatchTestReporterOptions
  ) {
    this._options = options;
    this._isCI = !!process.env.GITHUB_ACTIONS;
    this._mode =
      process.stdout.isTTY && !options.verbose && !this._isCI
        ? 'spinner'
        : 'grouped';
    this._total = packages.length;
    this._packages = new Map();

    for (const pkg of packages) {
      this._packages.set(pkg.name, {
        name: pkg.name,
        status: 'queued',
      });
    }
  }

  get mode(): 'spinner' | 'grouped' {
    return this._mode;
  }

  start(): void {
    if (this._mode === 'spinner') {
      console.log(
        OutputHelper.formatInfo(
          `Testing ${this._total} packages\n`
        )
      );
      // Hide cursor to avoid visible jumping during redraws
      process.stdout.write('\x1b[?25l');
      this._renderedLineCount = 0;
      this._render();
      this._renderInterval = setInterval(() => {
        this._spinnerFrame =
          (this._spinnerFrame + 1) % SPINNER_FRAMES.length;
        this._render();
      }, 80);
    } else {
      OutputHelper.info(
        `Testing ${this._total} packages`
      );
    }
  }

  onPackageStart(name: string): void {
    const state = this._packages.get(name);
    if (!state) return;

    state.status = 'building';
    state.startMs = Date.now();

    if (this._mode === 'grouped') {
      if (this._isCI) {
        console.log(`::group::${name}`);
      }
    }
  }

  onPackagePhaseChange(name: string, phase: TestPhase): void {
    const state = this._packages.get(name);
    if (!state) return;
    state.status = phase;
  }

  onPackageResult(result: BatchTestResult, bufferedOutput?: string[]): void {
    const state = this._packages.get(result.packageName);
    if (!state) return;

    state.status = result.success ? 'passed' : 'failed';
    state.durationMs = result.durationMs;
    state.bufferedOutput = bufferedOutput;
    this._completed++;

    this._allResults.push(result);
    if (!result.success) {
      this._failures.push(result);
    }

    if (this._mode === 'grouped') {
      this._printGroupedResult(result, bufferedOutput);
    }
  }

  stop(): void {
    if (this._mode === 'spinner') {
      if (this._renderInterval) {
        clearInterval(this._renderInterval);
        this._renderInterval = undefined;
      }
      this._render();
      // Show cursor again and print a newline after the spinner table
      process.stdout.write('\x1b[?25h');
      console.log('');

      // Print logs below the spinner table
      if (this._options.showLogs) {
        this._printAllLogs();
      } else {
        this._printFailureLogs();
      }
    }
  }

  private _printFailureLogs(): void {
    if (this._failures.length === 0) {
      return;
    }

    console.log(OutputHelper.formatError(`\n${this._failures.length} failed:\n`));

    for (const result of this._failures) {
      this._printResultLogs(result);
    }
  }

  private _printAllLogs(): void {
    for (const result of this._allResults) {
      this._printResultLogs(result);
    }
  }

  private _printResultLogs(result: BatchTestResult): void {
    const icon = result.success
      ? OutputHelper.formatSuccess('✓')
      : OutputHelper.formatError('✗');
    const status = result.success ? 'Passed' : 'FAILED';
    const formatted = result.success
      ? OutputHelper.formatSuccess(status)
      : OutputHelper.formatError(status);

    console.log(`${icon} ${OutputHelper.formatDim('──')} ${result.packageName} ${OutputHelper.formatDim('──')} ${formatted}`);

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

    for (const state of this._packages.values()) {
      const elapsed = state.startMs
        ? (state.durationMs ?? Date.now() - state.startMs)
        : 0;
      const time = elapsed > 0 ? formatDurationMs(elapsed) : '';

      let icon: string;
      let statusText: string;
      let line: string;

      switch (state.status) {
        case 'queued':
          icon = OutputHelper.formatDim('○');
          statusText = OutputHelper.formatDim('Queued');
          line = `  ${icon} ${OutputHelper.formatDim(state.name.padEnd(30))} ${statusText}`;
          break;
        case 'building':
          icon = OutputHelper.formatInfo(spinner);
          statusText = OutputHelper.formatInfo('⚙ Building');
          line = `  ${icon} ${state.name.padEnd(30)} ${statusText.padEnd(22)} ${OutputHelper.formatDim(time)}`;
          break;
        case 'uploading':
          icon = OutputHelper.formatInfo(spinner);
          statusText = OutputHelper.formatInfo('▲ Uploading');
          line = `  ${icon} ${state.name.padEnd(30)} ${statusText.padEnd(22)} ${OutputHelper.formatDim(time)}`;
          break;
        case 'scheduling':
          icon = OutputHelper.formatInfo(spinner);
          statusText = OutputHelper.formatInfo('◇ Scheduling');
          line = `  ${icon} ${state.name.padEnd(30)} ${statusText.padEnd(22)} ${OutputHelper.formatDim(time)}`;
          break;
        case 'executing':
          icon = OutputHelper.formatInfo(spinner);
          statusText = OutputHelper.formatInfo('▶ Executing');
          line = `  ${icon} ${state.name.padEnd(30)} ${statusText.padEnd(22)} ${OutputHelper.formatDim(time)}`;
          break;
        case 'passed':
          icon = OutputHelper.formatSuccess('✓');
          statusText = OutputHelper.formatSuccess('Passed');
          line = `  ${icon} ${state.name.padEnd(30)} ${statusText.padEnd(20)} ${OutputHelper.formatDim(time)}`;
          break;
        case 'failed':
          icon = OutputHelper.formatError('✗');
          statusText = OutputHelper.formatError('FAILED');
          line = `  ${icon} ${state.name.padEnd(30)} ${statusText.padEnd(20)} ${OutputHelper.formatDim(time)}`;
          break;
      }

      lines.push(line);
    }

    lines.push('');
    lines.push(
      OutputHelper.formatDim(`${this._completed}/${this._total} complete`)
    );

    // Build the entire frame as a single string: cursor-up + clear + content.
    // Writing it in one call prevents the terminal from briefly showing
    // the cleared state, which causes visible flicker.
    let frame = '';
    if (this._renderedLineCount > 0) {
      frame += `\x1b[${this._renderedLineCount}A\x1b[0J`;
    }
    frame += lines.join('\n') + '\n';
    process.stdout.write(frame);
    this._renderedLineCount = lines.length;
  }

  private _printGroupedResult(
    result: BatchTestResult,
    bufferedOutput?: string[]
  ): void {
    const headerWidth = 50;
    const label = ` ${result.packageName} `;
    const dashCount = Math.max(0, headerWidth - label.length);
    const leftDash = '─'.repeat(Math.floor(dashCount / 2));
    const rightDash = '─'.repeat(Math.ceil(dashCount / 2));
    const header = `${leftDash}${label}${rightDash}`;

    console.log(OutputHelper.formatDim(header));

    // Print buffered verbose output
    if (bufferedOutput && bufferedOutput.length > 0) {
      for (const line of bufferedOutput) {
        console.log(`  ${line}`);
      }
    }

    // Print result line
    const showLogs = this._options.showLogs || !result.success;
    const duration = formatDurationMs(result.durationMs);
    if (result.success) {
      console.log(
        `  ${OutputHelper.formatSuccess('✓')} ${OutputHelper.formatSuccess('Passed')} ${OutputHelper.formatDim(`(${duration})`)}`
      );
    } else {
      console.log(
        `  ${OutputHelper.formatError('✗')} ${OutputHelper.formatError('FAILED')} ${OutputHelper.formatDim(`(${duration})`)}`
      );
    }

    if (showLogs) {
      if (result.logs) {
        console.log(result.logs);
      } else {
        console.log(OutputHelper.formatDim('  (no output)'));
      }
      if (result.error) {
        console.log(`  ${OutputHelper.formatError(result.error)}`);
      }
    }

    if (this._isCI) {
      console.log('::endgroup::');
    }

    console.log('');
  }
}
