import chalk from 'chalk';

export type BoxOptions = {
  centered?: boolean;
};

/**
 * Helps with output
 */
export class OutputHelper {
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

  private static _stripAnsi = (text: string): string =>
    text.replace(/\x1b\[[0-9;]*m/g, '');

  /**
   * Helper method to put a box around the output
   */
  public static formatBox(message: string, options?: BoxOptions): string {
    const lines = message.trim().split('\n');
    const width = lines.reduce(
      (a, b) => Math.max(a, OutputHelper._stripAnsi(b).length),
      0
    );

    const centered = options?.centered ?? false;

    const surround = (text: string) => {
      const first = centered
        ? Math.floor((width - OutputHelper._stripAnsi(text).length) / 2)
        : 0;
      const last = width - OutputHelper._stripAnsi(text).length - first;
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
