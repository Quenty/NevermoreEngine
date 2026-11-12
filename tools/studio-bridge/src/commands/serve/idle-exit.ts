import { formatDurationMs } from '@quenty/cli-output-helpers/cli-utils';

export interface IdleExitOptions {
  clientIdleMs: number;
  noSessionMs: number;
  getClientCount: () => number;
  getSessionCount: () => number;
  onIdle: (reason: string) => void;
}

export class IdleExit {
  private _options: IdleExitOptions;
  private _clientTimer: ReturnType<typeof setTimeout> | undefined;
  private _sessionTimer: ReturnType<typeof setTimeout> | undefined;
  private _isStopped = false;

  constructor(options: IdleExitOptions) {
    this._options = options;
  }

  start(): void {
    this.noteClientActivity();
    this.noteSessionsChanged();
  }

  noteClientActivity(): void {
    if (this._isStopped) return;
    clearTimeout(this._clientTimer);
    this._clientTimer = this._arm(
      this._options.clientIdleMs,
      () => this.noteClientActivity(),
      `no CLI client activity for ${formatDurationMs(
        this._options.clientIdleMs
      )}`
    );
  }

  noteSessionsChanged(): void {
    if (this._isStopped) return;
    if (this._options.getSessionCount() > 0) {
      clearTimeout(this._sessionTimer);
      this._sessionTimer = undefined;
    } else if (this._sessionTimer === undefined) {
      this._armSessionTimer();
    }
  }

  stop(): void {
    this._isStopped = true;
    clearTimeout(this._clientTimer);
    clearTimeout(this._sessionTimer);
  }

  private _armSessionTimer(): void {
    this._sessionTimer = this._arm(
      this._options.noSessionMs,
      () => this._armSessionTimer(),
      `no Studio session connected for ${formatDurationMs(
        this._options.noSessionMs
      )}`
    );
  }

  private _arm(
    ms: number,
    rearm: () => void,
    reason: string
  ): ReturnType<typeof setTimeout> {
    return setTimeout(() => {
      if (this._isStopped) return;
      if (this._options.getClientCount() > 0) {
        rearm();
        return;
      }
      this.stop();
      this._options.onIdle(reason);
    }, ms);
  }
}
