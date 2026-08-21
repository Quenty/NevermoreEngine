interface DebounceTimer {
  SetLength(length: number): void;
  Restart(): void;
  IsRunning(): boolean;
  GetTimeRemaining(): number;
  IsDone(): boolean;
}

interface DebounceTimerConstructor {
  readonly ClassName: 'DebounceTimer';
  new (length: number): DebounceTimer;
}

export const DebounceTimer: DebounceTimerConstructor;
