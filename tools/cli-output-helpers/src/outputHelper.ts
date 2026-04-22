import chalk from 'chalk';
import { AsyncLocalStorage } from 'async_hooks';

export type BoxOptions = {
  centered?: boolean;
};

export interface OutputBuffer {
  lines: string[];
}

const _outputStorage = new AsyncLocalStorage<OutputBuffer>();

/**
 * Helps with output
 */
export class OutputHelper {
  private static _verbose: boolean = true;
  /**
   * Formats the error with markup
   * @param message Message to format
   * @returns Formatted string
   */
  public static formatError(message: string): string {
    return chalk.redBright(message);
  }

  /**
   * Formats the information message
   * @param message Message to format
   * @returns Formatted string
   */
  public static formatInfo(message: string): string {
    return chalk.cyanBright(message);
  }

  /**
   * Formats a warning message
   * @param message Message to format
   * @returns Formatted string
   */
  public static formatWarning(message: string): string {
    return chalk.yellowBright(message);
  }

  /**
   * Formats the information
   * @param message Message to format
   * @returns Formatted string
   */
  public static formatDescription(message: string): string {
    return chalk.greenBright(message);
  }

  /**
   * Formats the hint message
   * @param message Message to format
   * @returns Formatted string
   */
  public static formatHint(message: string): string {
    return chalk.magentaBright(message);
  }

  public static formatDim(message: string): string {
    return chalk.dim(message);
  }

  public static formatSuccess(message: string): string {
    return chalk.greenBright(message);
  }

  private static _hasAnsi = (text: string): boolean =>
    text.includes('\x1b[');

  /** Strip ANSI escape codes from terminal output. */
  public static stripAnsi = (text: string): string =>
    text.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '');

  /**
   * Helper method to put a box around the output
   */
  public static formatBox(message: string, options?: BoxOptions): string {
    const lines = message.trim().split('\n');
    const width = lines.reduce(
      (a, b) => Math.max(a, OutputHelper.stripAnsi(b).length),
      0
    );

    const centered = options?.centered ?? false;

    const surround = (text: string) => {
      const first = centered
        ? Math.floor((width - OutputHelper.stripAnsi(text).length) / 2)
        : 0;
      const last = width - OutputHelper.stripAnsi(text).length - first;
      return (
        '║   \x1b[0m' +
        ' '.repeat(first) +
        text +
        ' '.repeat(last) +
        '\x1b[31m   ║'
      );
    };

    const bar = '═'.repeat(width);
    const top = '\x1b[31m╔═══' + bar + '═══╗';
    const pad = surround('');
    const bottom = '╚═══' + bar + '═══╝\x1b[0m';

    return [top, pad, ...lines.map(surround), pad, bottom].join('\n');
  }

  /**
   * Logs information to the console
   * @param message Message to write
   */
  public static error(message: string): void {
    console.error(this._hasAnsi(message) ? message : this.formatError(message));
  }

  /**
   * Logs information to the console
   * @param message Message to write
   */
  public static info(message: string): void {
    console.log(this._hasAnsi(message) ? message : this.formatInfo(message));
  }

  /**
   * Sets whether verbose messages are printed.
   * Defaults to true. Batch runners set this to false to suppress
   * intermediate messages during concurrent execution.
   */
  public static setVerbose(verbose: boolean): void {
    this._verbose = verbose;
  }

  /**
   * Logs a verbose/intermediate message. Suppressed when verbose is false.
   * When running inside a buffered context (see runBuffered), messages are
   * captured to the buffer instead of printed.
   */
  public static verbose(message: string): void {
    if (!this._verbose) {
      return;
    }

    const formatted = this._hasAnsi(message) ? message : this.formatDim(message);
    const buffer = _outputStorage.getStore();
    if (buffer) {
      buffer.lines.push(formatted);
    } else {
      console.log(formatted);
    }
  }

  /**
   * Run an async function with output buffering. All OutputHelper.verbose()
   * calls inside the function are captured and returned alongside the result.
   * Used by batch runners to collect per-package output without interleaving.
   */
  public static async runBuffered<T>(
    fn: () => Promise<T>
  ): Promise<{ result: T; output: string[] }> {
    const buffer: OutputBuffer = { lines: [] };
    const result = await _outputStorage.run(buffer, fn);
    return { result, output: buffer.lines };
  }

  /**
   * Logs warning to the console
   * @param message Message to write
   */
  public static warn(message: string): void {
    console.log(this._hasAnsi(message) ? message : this.formatWarning(message));
  }

  /**
   * Logs hint to the console
   * @param message Message to write
   */
  public static hint(message: string): void {
    console.log(this._hasAnsi(message) ? message : this.formatHint(message));
  }

  /**
   * Renders a box around the message
   * @param message
   */
  public static box(message: string, options?: BoxOptions): void {
    console.log(this.formatBox(message, options));
  }
}
