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

  return {
    start(): void {
      if (rewrite) {
        process.stdout.write('\x1b[?25l'); // hide cursor
      }
      _render();
      _startInterval();
    },

    update(): void {
      _clearInterval();
      _render();
      _startInterval();
    },

    stop(): void {
      _clearInterval();
      _render();
      if (rewrite) {
        process.stdout.write('\x1b[?25h'); // show cursor
      }
    },
  };
}
