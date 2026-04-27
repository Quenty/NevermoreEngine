/**
 * Writes a rendered result to a file. Each onResult overwrites the file —
 * usable for both single writes and watch-mode file rewrites.
 *
 * Optional `binary` callback returns a Buffer to write instead of the
 * rendered text — used for screenshot/binary output.
 */

import * as fs from 'fs';
import { execSync } from 'child_process';
import { BaseResultReporter } from './result-reporter.js';

export interface FileResultReporterOptions<T> {
  outputPath: string;
  render: (result: T) => string;
  /** If provided and returns a Buffer, write that instead of the rendered text. */
  binary?: (result: T) => Buffer | undefined;
  /** Open the file with the platform's default viewer after the first write. */
  open?: boolean;
  /** Print a "Wrote output to <path>" status to stderr after each write. */
  reportPath?: boolean;
}

export class FileResultReporter<T = unknown> extends BaseResultReporter<T> {
  private _outputPath: string;
  private _render: (result: T) => string;
  private _binary?: (result: T) => Buffer | undefined;
  private _open: boolean;
  private _reportPath: boolean;
  private _hasOpened = false;

  constructor(options: FileResultReporterOptions<T>) {
    super();
    this._outputPath = options.outputPath;
    this._render = options.render;
    this._binary = options.binary;
    this._open = options.open ?? false;
    this._reportPath = options.reportPath ?? true;
  }

  override onResult(result: T): void {
    const buffer = this._binary?.(result);
    const isBinary = buffer !== undefined;
    if (isBinary) {
      fs.writeFileSync(this._outputPath, buffer);
    } else {
      fs.writeFileSync(this._outputPath, this._render(result), 'utf-8');
    }

    if (this._reportPath) {
      const label = isBinary ? 'binary output' : 'output';
      process.stderr.write(`Wrote ${label} to ${this._outputPath}\n`);
    }

    if (this._open && !this._hasOpened) {
      this._hasOpened = true;
      tryOpenFile(this._outputPath);
    }
  }
}

/** Best-effort open a file with the platform's default viewer. */
function tryOpenFile(filePath: string): void {
  try {
    const cmd =
      process.platform === 'darwin'
        ? 'open'
        : process.platform === 'win32'
        ? 'start ""'
        : 'xdg-open';
    execSync(`${cmd} ${JSON.stringify(filePath)}`, { stdio: 'ignore' });
  } catch {
    // Fire-and-forget — don't fail the command if open doesn't work
  }
}
