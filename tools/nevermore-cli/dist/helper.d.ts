/**
 * Helps with output
 */
export declare class OutputHelper {
    /**
     * Formats the error with markup
     * @param message Message to format
     * @returns Formatted string
     */
    static formatError(message: string): string;
    /**
     * Formats the information message
     * @param message Message to format
     * @returns Formatted string
     */
    static formatInfo(message: string): string;
    /**
     * Formats the information
     * @param message Message to format
     * @returns Formatted string
     */
    static formatDescription(message: string): string;
    /**
     * Formats the hint message
     * @param message Message to format
     * @returns Formatted string
     */
    static formatHint(message: string): string;
    /**
     * Logs information to the console
     * @param message Message to write
     */
    static error(message: string): void;
    /**
     * Logs information to the console
     * @param message Message to write
     */
    static info(message: string): void;
}
//# sourceMappingURL=helper.d.ts.map