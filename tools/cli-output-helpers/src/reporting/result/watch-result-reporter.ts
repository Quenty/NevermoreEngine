/**
 * Live-redraw reporter for watch-mode commands. Wraps the WatchRenderer —
 * stores the latest result and redraws via cursor manipulation.
 *
 * The first onResult starts the underlying renderer; subsequent calls update
 * it. stopAsync stops the renderer and restores the cursor.
 */

import { BaseResultReporter } from './result-reporter.js';
import { createWatchRenderer, type WatchRenderer } from './watch-renderer.js';

export interface WatchResultReporterOptions<T> {
  render: (result: T) => string;
  intervalMs?: number;
}

export class WatchResultReporter<T = unknown> extends BaseResultReporter<T> {
  private _renderer: WatchRenderer;
  private _latest: T | undefined;
  private _started = false;

  constructor(options: WatchResultReporterOptions<T>) {
    super();
    this._renderer = createWatchRenderer(
      () => (this._latest === undefined ? '' : options.render(this._latest)),
      { intervalMs: options.intervalMs }
    );
  }

  override onResult(result: T): void {
    this._latest = result;
    if (!this._started) {
      this._started = true;
      this._renderer.start();
    } else {
      this._renderer.update();
    }
  }

  override async stopAsync(): Promise<void> {
    if (this._started) {
      this._renderer.stop();
    }
  }
}
