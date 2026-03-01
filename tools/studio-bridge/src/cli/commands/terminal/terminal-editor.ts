/**
 * Raw-mode multi-line terminal editor with ANSI rendering.
 *
 * Provides a Claude Code-inspired input UI with:
 * - Multi-line editing (Enter = newline, Ctrl+Enter = submit)
 * - Cursor movement (arrows, Home/End)
 * - Dot-commands (.help, .exit, .run <file>, .clear)
 * - Status bar with keybinding hints
 */

import { EventEmitter } from 'events';
import * as fs from 'fs/promises';
import * as path from 'path';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface TerminalEditorEvents {
  submit: [buffer: string];
  'dot-command': [input: string];
  exit: [];
}

export interface TerminalEditorOptions {
  /**
   * Called to check whether a dot-command should be handled externally.
   * If it returns true, the command is emitted as a 'dot-command' event
   * instead of being handled by the built-in handler.
   */
  isExternalCommand?: (commandName: string) => boolean;

  /**
   * Custom help text to display for .help. When provided, replaces
   * the built-in help output.
   */
  helpText?: string;
}

// ---------------------------------------------------------------------------
// ANSI helpers
// ---------------------------------------------------------------------------

const ESC = '\x1b[';
const CLEAR_LINE = `${ESC}2K`;
const CURSOR_TO_COL1 = `${ESC}1G`;
const DIM = `${ESC}2m`;
const RESET = `${ESC}0m`;
const HIDE_CURSOR = `${ESC}?25l`;
const SHOW_CURSOR = `${ESC}?25h`;

function moveUp(n: number): string {
  return n > 0 ? `${ESC}${n}A` : '';
}

function moveToCol(col: number): string {
  return `${ESC}${col}G`;
}

// ---------------------------------------------------------------------------
// TerminalEditor
// ---------------------------------------------------------------------------

export class TerminalEditor extends EventEmitter {
  private _lines: string[] = [''];
  private _cursorRow = 0;
  private _cursorCol = 0;
  private _renderedLineCount = 0;
  /** Terminal row (0-indexed from top of rendered block) where the cursor sits */
  private _cursorTerminalRow = 0;
  private _active = false;
  private _onKeypress: ((data: Buffer) => void) | undefined;
  private _onResize: (() => void) | undefined;
  private _options: TerminalEditorOptions;

  constructor(options?: TerminalEditorOptions) {
    super();
    this._options = options ?? {};
  }

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  start(): void {
    if (this._active) return;
    this._active = true;

    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.setEncoding('utf-8');

    this._onKeypress = (data: Buffer) => this._handleInput(data.toString());
    // In raw mode with utf-8 encoding, data arrives as strings via 'data' event
    process.stdin.on('data', this._onKeypress as any);

    this._onResize = () => this._render();
    process.stdout.on('resize', this._onResize);

    this._render();
  }

  stop(): void {
    if (!this._active) return;

    // Erase the rendered editor UI before restoring the terminal
    this._eraseRendered();
    this._renderedLineCount = 0;

    this._active = false;

    if (this._onKeypress) {
      process.stdin.off('data', this._onKeypress as any);
      this._onKeypress = undefined;
    }
    if (this._onResize) {
      process.stdout.off('resize', this._onResize);
      this._onResize = undefined;
    }

    process.stdout.write(SHOW_CURSOR);

    try {
      process.stdin.setRawMode(false);
    } catch {
      // may fail if stdin is already closed
    }
    process.stdin.pause();
  }

  // -----------------------------------------------------------------------
  // Input handling
  // -----------------------------------------------------------------------

  private _handleInput(data: string): void {
    // Ctrl+C
    if (data === '\x03') {
      if (this._bufferText().length > 0) {
        this._lines = [''];
        this._cursorRow = 0;
        this._cursorCol = 0;
        this._render();
      } else {
        this.emit('exit');
      }
      return;
    }

    // Ctrl+D
    if (data === '\x04') {
      this.emit('exit');
      return;
    }

    // Ctrl+Enter (various terminal representations)
    // Most terminals: \x1b[13;5u or \x1b\r or similar
    // Windows Terminal sends \x0a for Ctrl+Enter in raw mode
    if (data === '\x0a' || data === '\x1b\r' || data === '\x1b\n') {
      this._submit();
      return;
    }

    // Check for CSI sequences with modifiers (e.g., \x1b[1;5A for Ctrl+Up)
    const csiMatch = data.match(/^\x1b\[(\d+)?;?(\d+)?([A-Z~u])/);
    if (csiMatch) {
      const [, param1, param2, code] = csiMatch;
      const modifier = param2 ? parseInt(param2, 10) : 0;
      const isCtrl = modifier === 5;

      // Ctrl+Enter via CSI u encoding: \x1b[13;5u
      if (code === 'u' && param1 === '13' && isCtrl) {
        this._submit();
        return;
      }

      switch (code) {
        case 'A': // Up
          this._moveCursorVertical(-1);
          this._render();
          return;
        case 'B': // Down
          this._moveCursorVertical(1);
          this._render();
          return;
        case 'C': // Right
          this._moveCursorHorizontal(1);
          this._render();
          return;
        case 'D': // Left
          this._moveCursorHorizontal(-1);
          this._render();
          return;
        case 'H': // Home
          this._cursorCol = 0;
          this._render();
          return;
        case 'F': // End
          this._cursorCol = this._lines[this._cursorRow].length;
          this._render();
          return;
        case '~': {
          const keyCode = param1 ? parseInt(param1, 10) : 0;
          if (keyCode === 3) {
            // Delete key
            this._deleteForward();
            this._render();
          } else if (keyCode === 1) {
            // Home
            this._cursorCol = 0;
            this._render();
          } else if (keyCode === 4) {
            // End
            this._cursorCol = this._lines[this._cursorRow].length;
            this._render();
          }
          return;
        }
      }
      return;
    }

    // Plain escape sequence (Alt or other)
    if (data.startsWith('\x1b')) {
      // Ignore unrecognized escape sequences
      return;
    }

    // Enter (carriage return) — insert newline
    if (data === '\r') {
      this._insertNewline();
      this._render();
      return;
    }

    // Backspace
    if (data === '\x7f' || data === '\b') {
      this._deleteBackward();
      this._render();
      return;
    }

    // Tab
    if (data === '\t') {
      this._insertText('  ');
      this._render();
      return;
    }

    // Printable characters
    if (data.length > 0 && data.charCodeAt(0) >= 32) {
      this._insertText(data);
      this._render();
    }
  }

  // -----------------------------------------------------------------------
  // Buffer operations
  // -----------------------------------------------------------------------

  private _bufferText(): string {
    return this._lines.join('\n');
  }

  private _insertText(text: string): void {
    const line = this._lines[this._cursorRow];
    this._lines[this._cursorRow] =
      line.slice(0, this._cursorCol) + text + line.slice(this._cursorCol);
    this._cursorCol += text.length;
  }

  private _insertNewline(): void {
    const line = this._lines[this._cursorRow];
    const before = line.slice(0, this._cursorCol);
    const after = line.slice(this._cursorCol);
    this._lines[this._cursorRow] = before;
    this._lines.splice(this._cursorRow + 1, 0, after);
    this._cursorRow++;
    this._cursorCol = 0;
  }

  private _deleteBackward(): void {
    if (this._cursorCol > 0) {
      const line = this._lines[this._cursorRow];
      this._lines[this._cursorRow] =
        line.slice(0, this._cursorCol - 1) + line.slice(this._cursorCol);
      this._cursorCol--;
    } else if (this._cursorRow > 0) {
      // Merge with previous line
      const prevLine = this._lines[this._cursorRow - 1];
      this._lines[this._cursorRow - 1] =
        prevLine + this._lines[this._cursorRow];
      this._lines.splice(this._cursorRow, 1);
      this._cursorRow--;
      this._cursorCol = prevLine.length;
    }
  }

  private _deleteForward(): void {
    const line = this._lines[this._cursorRow];
    if (this._cursorCol < line.length) {
      this._lines[this._cursorRow] =
        line.slice(0, this._cursorCol) + line.slice(this._cursorCol + 1);
    } else if (this._cursorRow < this._lines.length - 1) {
      // Merge with next line
      this._lines[this._cursorRow] =
        line + this._lines[this._cursorRow + 1];
      this._lines.splice(this._cursorRow + 1, 1);
    }
  }

  private _moveCursorHorizontal(delta: number): void {
    if (delta > 0) {
      const line = this._lines[this._cursorRow];
      if (this._cursorCol < line.length) {
        this._cursorCol++;
      } else if (this._cursorRow < this._lines.length - 1) {
        this._cursorRow++;
        this._cursorCol = 0;
      }
    } else {
      if (this._cursorCol > 0) {
        this._cursorCol--;
      } else if (this._cursorRow > 0) {
        this._cursorRow--;
        this._cursorCol = this._lines[this._cursorRow].length;
      }
    }
  }

  private _moveCursorVertical(delta: number): void {
    const newRow = this._cursorRow + delta;
    if (newRow >= 0 && newRow < this._lines.length) {
      this._cursorRow = newRow;
      this._cursorCol = Math.min(
        this._cursorCol,
        this._lines[this._cursorRow].length
      );
    }
  }

  // -----------------------------------------------------------------------
  // Submit / dot-commands
  // -----------------------------------------------------------------------

  private _submit(): void {
    const text = this._bufferText().trimEnd();

    // Dot-commands
    if (text.startsWith('.')) {
      this._handleDotCommand(text);
      return;
    }

    if (text.length === 0) return;

    this._clearEditor();
    this.emit('submit', text);
  }

  private _handleDotCommand(text: string): void {
    const parts = text.split(/\s+/);
    const cmd = parts[0].toLowerCase();

    // Check if this command should be handled externally (bridge commands)
    if (this._options.isExternalCommand?.(cmd)) {
      this._clearEditor();
      this.emit('dot-command', text);
      return;
    }

    switch (cmd) {
      case '.help':
        this._clearEditor();
        if (this._options.helpText) {
          console.log(this._options.helpText);
        } else {
          console.log(
            [
              '',
              `${DIM}Commands:${RESET}`,
              `  .help          Show this help message`,
              `  .exit          Exit terminal mode`,
              `  .run <file>    Read and execute a Luau file`,
              `  .clear         Clear the editor buffer`,
              '',
              `${DIM}Keybindings:${RESET}`,
              `  Enter          New line`,
              `  Ctrl+Enter     Execute buffer`,
              `  Ctrl+C         Clear buffer (or exit if empty)`,
              `  Ctrl+D         Exit`,
              `  Tab            Insert 2 spaces`,
              `  Arrow keys     Move cursor`,
              '',
            ].join('\n')
          );
        }
        this._render();
        break;

      case '.exit':
        this._clearEditor();
        this.emit('exit');
        break;

      case '.run': {
        const filePath = parts.slice(1).join(' ').trim();
        if (!filePath) {
          this._clearEditor();
          console.log(`${DIM}Usage: .run <file.lua>${RESET}\n`);
          this._render();
          return;
        }
        this._clearEditor();
        this._runFile(filePath);
        break;
      }

      case '.clear':
        this._lines = [''];
        this._cursorRow = 0;
        this._cursorCol = 0;
        this._render();
        break;

      default:
        this._clearEditor();
        console.log(
          `Unknown command. Type .help for available commands.\n`
        );
        this._render();
    }
  }

  private async _runFile(filePath: string): Promise<void> {
    try {
      const resolved = path.resolve(filePath);
      const content = await fs.readFile(resolved, 'utf-8');
      this.emit('submit', content);
    } catch (err) {
      console.log(
        `Error reading file: ${err instanceof Error ? err.message : String(err)}\n`
      );
      this._render();
    }
  }

  // -----------------------------------------------------------------------
  // Rendering
  // -----------------------------------------------------------------------

  private _clearEditor(): void {
    // Move to start of rendered area and clear it
    this._eraseRendered();
    this._renderedLineCount = 0;
    this._lines = [''];
    this._cursorRow = 0;
    this._cursorCol = 0;
  }

  private _eraseRendered(): void {
    if (this._renderedLineCount === 0) return;

    let out = '';
    // Move cursor from its current terminal row up to the first rendered line
    out += moveUp(this._cursorTerminalRow);
    // Clear each line top-to-bottom
    for (let i = 0; i < this._renderedLineCount; i++) {
      out += CURSOR_TO_COL1 + CLEAR_LINE;
      if (i < this._renderedLineCount - 1) {
        out += `${ESC}1B`; // move down
      }
    }
    // Move back to top
    if (this._renderedLineCount > 1) {
      out += moveUp(this._renderedLineCount - 1);
    }
    out += CURSOR_TO_COL1;
    process.stdout.write(out);
  }

  _render(): void {
    if (!this._active) return;

    const width = process.stdout.columns || 80;
    const divider = '\u2500'.repeat(width);

    // Erase previous render
    this._eraseRendered();

    let out = HIDE_CURSOR;

    // Top divider
    out += `${DIM}${divider}${RESET}\n`;

    // Buffer lines with prompt
    for (let i = 0; i < this._lines.length; i++) {
      const prefix = i === 0 ? '\u276F ' : '  ';
      out += `${prefix}${this._lines[i]}\n`;
    }

    // Bottom divider
    out += `${DIM}${divider}${RESET}\n`;

    // Status bar
    const lineInfo =
      this._lines.length > 1 ? ` \u00B7 ${this._lines.length} lines` : '';
    const statusText = `  ctrl+enter to run \u00B7 ctrl+c to clear \u00B7 .help for commands${lineInfo}`;
    out += `${DIM}${statusText}${RESET}`;

    // Total rendered lines: 1 (top divider) + lines.length + 1 (bottom divider) + 1 (status)
    const totalLines = this._lines.length + 3;

    // Position cursor: move up from status bar to the correct buffer line,
    // then move to the correct column.
    // Cursor's target terminal row (0-indexed): top divider(0) + cursorRow+1
    const cursorTermRow = this._cursorRow + 1; // +1 for top divider
    const linesFromBottom = totalLines - 1 - cursorTermRow;
    if (linesFromBottom > 0) {
      out += moveUp(linesFromBottom);
    }
    const prefix = 2; // "❯ " or "  " both 2 chars
    out += moveToCol(prefix + this._cursorCol + 1);
    out += SHOW_CURSOR;

    process.stdout.write(out);
    this._renderedLineCount = totalLines;
    this._cursorTerminalRow = cursorTermRow;
  }
}
