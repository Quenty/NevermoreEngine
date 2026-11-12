import * as fs from 'fs';
import * as path from 'path';
import { BaseResultReporter } from './result-reporter.js';
import { tryOpenFile } from './file-result-reporter.js';

export interface OutputFile {
  relativePath: string;
  data: Buffer | string;
}

export interface DirectoryResultReporterOptions<T> {
  outputDir: string;
  files: (result: T) => OutputFile[];
  render: (result: T) => string;
  open?: boolean;
}

export class DirectoryResultReporter<
  T = unknown
> extends BaseResultReporter<T> {
  private _outputDir: string;
  private _files: (result: T) => OutputFile[];
  private _render: (result: T) => string;
  private _open: boolean;
  private _hasOpened = false;

  constructor(options: DirectoryResultReporterOptions<T>) {
    super();
    this._outputDir = options.outputDir;
    this._files = options.files;
    this._render = options.render;
    this._open = options.open ?? false;
  }

  override onResult(result: T): void {
    const files = this._files(result);
    fs.mkdirSync(this._outputDir, { recursive: true });
    for (const file of files) {
      const filePath = path.join(this._outputDir, file.relativePath);
      if (typeof file.data === 'string') {
        fs.writeFileSync(filePath, file.data, 'utf-8');
      } else {
        fs.writeFileSync(filePath, file.data);
      }
    }
    process.stderr.write(`Wrote ${files.length} files to ${this._outputDir}\n`);

    const text = this._render(result);
    if (text !== '') {
      console.log(text);
    }

    if (this._open && !this._hasOpened) {
      this._hasOpened = true;
      tryOpenFile(this._outputDir);
    }
  }
}
