/**
 * Live-updating renderer for watch/monitoring commands. In TTY mode,
 * rewrites output in-place using cursor control. In non-TTY mode,
 * appends new output only when it changes.
 */

export interface WatchRendererOptions {
  intervalMs?: number;
  rewrite?: boolean;
}

export interface WatchRenderer {
  start(): void;
  update(): void;
  stop(): void;
}

export function createWatchRenderer(
  render: () => string,
  options?: WatchRendererOptions
): WatchRenderer {
  const intervalMs = options?.intervalMs ?? 1000;
  const rewrite = options?.rewrite ?? (process.stdout.isTTY ? true : false);

  let _intervalHandle: ReturnType<typeof setInterval> | null = null;
  let _previousOutput: string = '';
  let _previousLineCount: number = 0;

  function _render(): void {
    const output = render();

    if (rewrite) {
      // TTY rewrite mode: move cursor up and clear previous output
      if (_previousLineCount > 0) {
        process.stdout.write(`\x1b[${_previousLineCount}A\x1b[J`);
      }
      process.stdout.write(output + '\n');
      _previousLineCount = output.split('\n').length;
    } else {
      // Non-TTY append mode: only write when content changes
      if (output !== _previousOutput) {
        process.stdout.write(output + '\n');
      }
    }

    _previousOutput = output;
  }

  function _startInterval(): void {
    _intervalHandle = setInterval(_render, intervalMs);
  }

  function _clearInterval(): void {
    if (_intervalHandle !== null) {
      clearInterval(_intervalHandle);
      _intervalHandle = null;
    }
  }

  let _cursorHidden = false;
  let _signalsBound = false;

  function _showCursor(): void {
    if (_cursorHidden) {
      _cursorHidden = false;
      process.stdout.write('\x1b[?25h');
    }
  }

  function _onSignal(signal: NodeJS.Signals): void {
    _clearInterval();
    _showCursor();
    // Restore default behavior so the process actually exits
    process.removeListener('SIGINT', _onSignal);
    process.removeListener('SIGTERM', _onSignal);
    process.kill(process.pid, signal);
  }

  function _bindSignals(): void {
    if (_signalsBound) return;
    _signalsBound = true;
    process.once('SIGINT', _onSignal);
    process.once('SIGTERM', _onSignal);
  }

  function _unbindSignals(): void {
    if (!_signalsBound) return;
    _signalsBound = false;
    process.removeListener('SIGINT', _onSignal);
    process.removeListener('SIGTERM', _onSignal);
  }

  return {
    start(): void {
      if (rewrite) {
        process.stdout.write('\x1b[?25l'); // hide cursor
        _cursorHidden = true;
        _bindSignals();
      }
      try {
        _render();
      } catch (err) {
        _showCursor();
        _unbindSignals();
        throw err;
      }
      _startInterval();
    },

    update(): void {
      _clearInterval();
      try {
        _render();
      } catch (err) {
        _showCursor();
        _unbindSignals();
        throw err;
      }
      _startInterval();
    },

    stop(): void {
      _clearInterval();
      try {
        _render();
      } finally {
        _showCursor();
        _unbindSignals();
      }
    },
  };
}
