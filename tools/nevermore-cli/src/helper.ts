import chalk from 'chalk';

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

  /**
   * Logs information to the console
   * @param message Message to write
   */
  public static error(message: string) {
    console.error(this.formatError(message));
  }

  /**
   * Logs information to the console
   * @param message Message to write
   */
  public static info(message: string) {
    console.log(this.formatInfo(message));
  }
}
