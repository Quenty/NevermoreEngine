"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OutputHelper = void 0;
const chalk_1 = __importDefault(require("chalk"));
/**
 * Helps with output
 */
class OutputHelper {
    /**
     * Formats the error with markup
     * @param message Message to format
     * @returns Formatted string
     */
    static formatError(message) {
        return chalk_1.default.redBright(message);
    }
    /**
     * Formats the information message
     * @param message Message to format
     * @returns Formatted string
     */
    static formatInfo(message) {
        return chalk_1.default.cyanBright(message);
    }
    /**
     * Formats the information
     * @param message Message to format
     * @returns Formatted string
     */
    static formatDescription(message) {
        return chalk_1.default.greenBright(message);
    }
    /**
     * Formats the hint message
     * @param message Message to format
     * @returns Formatted string
     */
    static formatHint(message) {
        return chalk_1.default.magentaBright(message);
    }
    /**
     * Logs information to the console
     * @param message Message to write
     */
    static error(message) {
        console.error(this.formatError(message));
    }
    /**
     * Logs information to the console
     * @param message Message to write
     */
    static info(message) {
        console.log(this.formatInfo(message));
    }
}
exports.OutputHelper = OutputHelper;
//# sourceMappingURL=helper.js.map